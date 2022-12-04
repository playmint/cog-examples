// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    Attribute,
    AttributeKind,
    State,
    NodeData,
    EdgeType,
    EdgeData,
    NodeType,
    NodeIDUtils,
    NodeTypeUtils,
    NodeID
} from "cog/State.sol";
import {
    Action,
    Context,
    Rule,
    BaseDispatcher
} from "cog/Dispatcher.sol";
import {
    Game,
    BasicGame
} from "cog/Game.sol";

import {StateGraph} from "cog/StateGraph.sol";

// ----------------------------------
// define some constants/enums
// ----------------------------------

enum Direction {
    NORTH,
    NORTHEAST,
    EAST,
    SOUTHEAST,
    SOUTH,
    SOUTHWEST,
    WEST,
    NORTHWEST
}

// ----------------------------------
// define some actions
// ----------------------------------

interface Actions {
    function RESET_MAP() external;
    function REVEAL_SEED(NodeID seedID, uint32 entropy) external;
    function SPAWN_SEEKER(uint32 sid, uint8 x, uint8 y, uint8 str) external;
    function MOVE_SEEKER(uint32 sid, Direction dir) external;
}

// ----------------------------------
// define some schema types
// ----------------------------------


contract Seed is NodeType {
    function ID(uint32 blk) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, blk);
    }
    function getAttributeValues(State s, NodeID id) public view returns (uint32 blk) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID id, NodeData /*data*/) public pure returns (uint32 blk) {
        (,, blk) = NodeIDUtils.decodeID(id);
        return blk;
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (uint32 blk) = getAttributeValues(id, data);
        attrs = new Attribute[](2);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("SEED");
        attrs[1].name = "block";
        attrs[1].kind = AttributeKind.UINT32;
        attrs[1].value = bytes32(uint(blk));
    }
}

contract Tile is NodeType {
    enum Contents {
        UNDISCOVERED,
        BLOCKER,
        GRASS,
        CORN
    }
    function ID(uint32 x, uint32 y) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, x, y);
    }
    function setAttributeValues(State s, NodeID id, Contents c) public returns (State) {
        return s.setNode(
            id,
            NodeData.wrap(uint256(c))
        );
    }
    function getAttributeValues(State s, NodeID id) public view returns (Contents c, uint32 x, uint32 y) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID id, NodeData data) public pure returns (Contents c, uint32 x, uint32 y) {
        (,x,y) = NodeIDUtils.decodeID(id);
        c = Contents(uint8(NodeData.unwrap(data)));
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (Contents c, uint32 x, uint32 y) = getAttributeValues(id, data);
        attrs = new Attribute[](4);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("TILE");
        attrs[1].name = "contents";
        attrs[1].kind = AttributeKind.UINT8;
        attrs[1].value = bytes32(uint(c));
        attrs[2].name = "x";
        attrs[2].kind = AttributeKind.UINT32;
        attrs[2].value = bytes32(uint(x));
        attrs[3].name = "y";
        attrs[3].kind = AttributeKind.UINT32;
        attrs[3].value = bytes32(uint(y));
    }
}

contract Resource is NodeType {
    enum Kind {
        UNKNOWN,
        CORN
    }
    function ID(Kind k) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, uint32(k));
    }
    function getAttributeValues(State s, NodeID id) public view returns (Kind k) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID id, NodeData /*data*/) public pure returns (Kind k) {
        (,, uint32 kid) = NodeIDUtils.decodeID(id);
        return Kind(kid);
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (Kind k) = getAttributeValues(id, data);
        attrs = new Attribute[](2);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("RESOURCE");
        attrs[1].name = "resource";
        attrs[1].kind = AttributeKind.UINT8;
        attrs[1].value = bytes32(uint(k));
    }
}

contract Seeker is NodeType {
    function ID(uint32 id) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, uint32(id));
    }
    function setAttributeValues(State s, NodeID id, uint8 str) public returns (State) {
        return s.setNode(
            id,
            NodeData.wrap(uint256(str))
        );
    }
    function getAttributeValues(State s, NodeID id) public view returns (uint8 str) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID /*id*/, NodeData data) public pure returns (uint8 str) {
        str = uint8(NodeData.unwrap(data));
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (,, uint32 sid) = NodeIDUtils.decodeID(id);
        (uint8 str) = getAttributeValues(id, data);
        attrs = new Attribute[](3);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("SEEKER");
        attrs[1].name = "strength";
        attrs[1].kind = AttributeKind.UINT8;
        attrs[1].value = bytes32(uint(str));
        attrs[2].name = "sid";
        attrs[2].kind = AttributeKind.UINT32;
        attrs[2].value = bytes32(uint(sid));
    }
}

// ----------------------------------
// define some schema relationships
// ----------------------------------

contract HasOwner is EdgeType {
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("HAS_OWNER");
    }
}
contract HasLocation is EdgeType {
    function getCoords(State s, NodeID srcNodeID) public view returns (uint32 x, uint32 y) {
        NodeID id = s.getEdge(this, srcNodeID).nodeID;
        (,x,y) = NodeIDUtils.decodeID(id);
    }
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("HAS_LOCATION");
    }
}
contract HasResource is EdgeType {
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("HAS_RESOURCE");
    }
}
contract ProvidesEntropyTo is EdgeType {
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("PROVIDES_ENTROPY_TO");
    }
}

// -------------------------------------------------------
// define some helpers for working with state (optional)
// -------------------------------------------------------

// library StateUtils {
//     function setSeed(State g, uint256 blockNumber) returns (NodeData) {
//         g.setNode(

//         );
//     }
// }


// // ----------------------------------
// // define some game rules
// // ----------------------------------

contract ResetRule is Rule {

    Tile TILE;

    constructor(
        Tile tileNodeTypeAddr
    ) {
        TILE = tileNodeTypeAddr;
    }

    function reduce(State state, bytes calldata action, Context calldata /*ctx*/) public returns (State) {
        if (bytes4(action) == Actions.RESET_MAP.selector) {
            // draw a grid of tiles encoding the x/y into the ID
            for (uint8 x=0; x<32; x++) {
                for (uint8 y=0; y<32; y++) {
                    state = state.setNode(
                        TILE.ID(x, y),
                        getInitialNodeData(x, y)
                    );
                }
            }
        }
        return state;
    }

    function getInitialContents(uint8 x, uint8 y) private pure returns (Tile.Contents) {
        if (x == 0 || y == 0 || x == 31 || y == 31) { // grass around the edge
            return Tile.Contents.GRASS;
        } else { // everything else unknown
            return Tile.Contents.UNDISCOVERED;
        }
    }

    function getInitialNodeData(uint8 x, uint8 y) private pure returns (NodeData) {
        return NodeData.wrap(uint256(getInitialContents(x, y)));
    }

}

contract SpawnSeekerRule is Rule {

    Seeker SEEKER;
    Tile TILE;
    HasLocation HAS_LOCATION;
    HasOwner HAS_OWNER;

    constructor(
        Seeker seekerNodeTypeAddr,
        Tile tileNodeTypeAddr,
        HasLocation hasLocationAddr,
        HasOwner hasOwnerAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        HAS_OWNER = hasOwnerAddr;
    }

    function reduce(State state, bytes calldata action, Context calldata ctx) public returns (State) {
        if (bytes4(action) == Actions.SPAWN_SEEKER.selector) {
            (uint32 sid, uint8 x, uint8 y, uint8 str) = abi.decode(action[4:], (uint32, uint8, uint8, uint8));
            NodeID id = SEEKER.ID(sid);
            // set seeker stat
            state = SEEKER.setAttributeValues(
                state,
                id,
                str
            );
            // set the seeker's owner
            // still deciding if Accounts should be in the stategraph or stay outside :thinkies:
            // for now, just hack em in by treating the account addr as a nodetype
            state = state.setEdge(
                HAS_OWNER,
                id,
                EdgeData({
                    nodeID: NodeTypeUtils.ID( NodeType(ctx.sender), 0, 0),
                    weight: 0
                })
            );
            // set location by pointing a HAS_LOCATION at the tile
            state = state.setEdge(
                HAS_LOCATION,
                id,
                EdgeData({
                    nodeID: TILE.ID(x, y),
                    weight: 0
                })
            );
        }
        return state;
    }

    function getInitialContents(uint8 x, uint8 y) private pure returns (Tile.Contents) {
        if (x == 0 || y == 0 || x == 31 || y == 31) { // grass around the edge
            return Tile.Contents.GRASS;
        } else { // everything else unknown
            return Tile.Contents.UNDISCOVERED;
        }
    }

    function getInitialNodeData(uint8 x, uint8 y) private pure returns (NodeData) {
        return NodeData.wrap(uint256(getInitialContents(x, y)));
    }

}

contract MovementRule is Rule {

    Seeker SEEKER;
    Tile TILE;
    HasLocation HAS_LOCATION;

    constructor(
        Seeker seekerNodeTypeAddr,
        Tile tileNodeTypeAddr,
        HasLocation hasLocationAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
    }

    function reduce(State state, bytes calldata action, Context calldata /*ctx*/) public returns (State) {
        // movement is one tile at a time
        // you can only move onto an discovered tile
        if (bytes4(action) == Actions.MOVE_SEEKER.selector) {
            (uint32 sid, Direction dir) = abi.decode(action[4:], (uint32, Direction));
            (uint32 x, uint32 y) = HAS_LOCATION.getCoords(
                state,
                SEEKER.ID(sid)
            );
            int xx = int(uint(x));
            int yy = int(uint(y));
            if (dir == Direction.NORTH) {
                yy++;
            } else if (dir == Direction.NORTHEAST) {
                xx++;
                yy++;
            } else if (dir == Direction.EAST) {
                xx++;
            } else if (dir == Direction.SOUTHEAST) {
                xx++;
                yy--;
            } else if (dir == Direction.SOUTH) {
                yy--;
            } else if (dir == Direction.SOUTHWEST) {
                xx--;
                yy--;
            } else if (dir == Direction.WEST) {
                xx--;
            } else if (dir == Direction.NORTHWEST) {
                xx--;
                yy--;
            }
            if (xx<0) {
                xx = 0;
            } else if (xx>31) {
                xx = 31;
            }
            if (yy<0) {
                yy = 0;
            } else if (yy>31) {
                yy = 31;
            }
            NodeID targetTile = TILE.ID(uint32(uint(xx)),uint32(uint(yy)));
            (Tile.Contents c,,) = TILE.getAttributeValues(
                state,
                targetTile
            );
            if (c == Tile.Contents.UNDISCOVERED) {
                // illegal move, ignore it
                return state;
            }
            // update seeker location
            state = state.setEdge(
                HAS_LOCATION,
                SEEKER.ID(sid),
                EdgeData({
                    nodeID: targetTile,
                    weight: 0
                })
            );
        }
        return state;
    }

}


contract ScoutingRule is Rule {

    Seeker SEEKER;
    Seed SEED;
    Tile TILE;
    HasLocation HAS_LOCATION;
    ProvidesEntropyTo PROVIDES_ENTROPY_TO;

    constructor(
        Seeker seekerNodeTypeAddr,
        Seed seedNodeTypeAddr,
        Tile tileNodeTypeAddr,
        HasLocation hasLocationAddr,
        ProvidesEntropyTo providesEntropyEdgeAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        SEED = seedNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        PROVIDES_ENTROPY_TO = providesEntropyEdgeAddr;
    }

    function reduce(State state, bytes calldata action, Context calldata ctx) public returns (State) {
        // scouting tiles is performed in two stages
        // stage1: we commit to a SEED during a MOVE_SEEKER or SPAWN_SEEKER action
        // stage2: occurs when a REVEAL_SEED action is processed
        if (bytes4(action) == Actions.SPAWN_SEEKER.selector) {

            (, uint8 x, uint8 y,) = abi.decode(action[4:], (uint32, uint8, uint8, uint8));
            state = commitAdjacent(state, ctx, int(uint(x)), int(uint(y)));

        } else if (bytes4(action) == Actions.MOVE_SEEKER.selector) {

            (uint32 sid,) = abi.decode(action[4:], (uint32, Direction));
            (uint32 x, uint32 y) = HAS_LOCATION.getCoords(state, SEEKER.ID(sid));
            state = commitAdjacent(state, ctx, int(uint(x)), int(uint(y)));

        } else if (bytes4(action) == Actions.REVEAL_SEED.selector) {

            (NodeID seed, uint32 entropy) = abi.decode(action[4:], (NodeID, uint32));
            state = revealTiles(state, seed, entropy);

        }
        return state;
    }

    function commitAdjacent(State state, Context calldata ctx, int x, int y) private returns (State) {
        int xx;
        int yy;
        for (uint8 i=0; i<8; i++) {
            if (i == 0) {
                xx = x-1;
                yy = y+1;
            } else if (i == 1) {
                xx = x;
                yy = y+1;
            } else if (i == 2) {
                xx = x+1;
                yy = y+1;
            } else if (i == 3) {
                xx = x+1;
                yy = y;
            } else if (i == 4) {
                xx = x-1;
                yy = y-1;
            } else if (i == 5) {
                xx = x;
                yy = y-1;
            } else if (i == 6) {
                xx = x-1;
                yy = y-1;
            } else if (i == 7) {
                xx = x-1;
                yy = y;
            }

            if (xx < 0 || yy < 0) {
                continue;
            }
            NodeID tileID = TILE.ID(uint32(uint(xx)),uint32(uint(yy)));
            (Tile.Contents c,,) = TILE.getAttributeValues(
                state,
                tileID
            );
            if (c == Tile.Contents.UNDISCOVERED) {
                // commit rile contents to a future SEED
                // appending allows us to tie multiple things to the
                // same seed ... but also means there might be multiple
                // edges pointing to the same thing... we could fetch the
                // edges to check if we need to add another one, but it's
                // probably cheaper to just append another one and not worry about it
                state.appendEdge(
                    PROVIDES_ENTROPY_TO,
                    SEED.ID(ctx.clock),
                    EdgeData({
                        nodeID: tileID,
                        weight: 0
                    })
                );
            }
        }
        return state;
    }

    function revealTiles(State state, NodeID seedID, uint32 entropy) private returns (State) {
        EdgeData[] memory targetTiles = state.getEdges(
            PROVIDES_ENTROPY_TO,
            seedID
        );
        for (uint i=0; i<targetTiles.length; i++) {
            (Tile.Contents c, uint32 x, uint32 y) = TILE.getAttributeValues(
                state,
                targetTiles[i].nodeID
            );
            if (c != Tile.Contents.UNDISCOVERED) {
                continue;
            }
            uint8 r = random(entropy, x, y);
            if (r > 90) {
                c = Tile.Contents.CORN;
            } else {
                c = Tile.Contents.GRASS;
            }
            state = TILE.setAttributeValues(
                state,
                targetTiles[i].nodeID,
                c
            );
        }
        return state;
    }

    function random(uint32 entropy, uint32 x, uint32 y) public pure returns(uint8){
        return uint8(uint( keccak256(abi.encodePacked(x, y, entropy)) ) % 255);
    }

}

contract HarvestRule is Rule {

    Seeker SEEKER;
    Tile TILE;
    Resource RESOURCE;
    HasLocation HAS_LOCATION;
    HasResource HAS_RESOURCE;

    constructor(
        Seeker seekerNodeTypeAddr,
        Tile tileNodeTypeAddr,
        Resource resourceNodeTypeAddr,
        HasLocation hasLocationAddr,
        HasResource hasResourceAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        RESOURCE = resourceNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        HAS_RESOURCE = hasResourceAddr;
    }

    function reduce(State state, bytes calldata action, Context calldata /*ctx*/) public returns (State) {
        // harvesting is triggered when you move to tile with CORN on it
        // standing on a CORN tile converts the tile to a GRASS tile
        // and increases the seeker's CORN balance in their STORAGE
        if (bytes4(action) == Actions.MOVE_SEEKER.selector) {
            (uint32 sid,) = abi.decode(action[4:], (uint32, Direction));

            (uint32 x, uint32 y) = HAS_LOCATION.getCoords(
                state,
                SEEKER.ID(sid)
            );
            NodeID targetTile = TILE.ID(x,y);
            (Tile.Contents c,,) = TILE.getAttributeValues(
                state,
                targetTile
            );
            if (c == Tile.Contents.CORN) {
                // convert tile to grass
                c = Tile.Contents.GRASS;
                state = TILE.setAttributeValues(
                    state,
                    targetTile,
                    c
                );
                // get current balance of corn
                uint32 balance = state.getEdge(
                    HAS_RESOURCE,
                    SEEKER.ID(sid)
                ).weight;
                // increase the balance
                balance++;
                // store new balance
                state = state.setEdge(
                    HAS_RESOURCE,
                    SEEKER.ID(sid),
                    EdgeData({
                        nodeID: RESOURCE.ID(Resource.Kind.CORN),
                        weight: balance
                    })
                );
            }

        }
        return state;
    }

}


// ----------------------------------
// define a game as a set of rules
// ----------------------------------

contract CornSeekers is Game, BasicGame {

    // node type refs
    Seeker public SEEKER;
    Seed public SEED;
    Tile public TILE;
    Resource public RESOURCE;

    // edge refs
    ProvidesEntropyTo public PROVIDES_ENTROPY_TO;
    HasOwner public HAS_OWNER;
    HasLocation public HAS_LOCATION;
    HasResource public HAS_RESOURCE;

    constructor() BasicGame("CORNSEEKERS") {
        // setup node types
        SEEKER = new Seeker();
        SEED = new Seed();
        TILE = new Tile();
        RESOURCE = new Resource();

        // setup edge types
        PROVIDES_ENTROPY_TO = new ProvidesEntropyTo();
        HAS_OWNER = new HasOwner();
        HAS_LOCATION = new HasLocation();
        HAS_RESOURCE = new HasResource();

        // setup rules
        dispatcher.registerRule(new ResetRule(
            Tile(address(TILE))
        ));
        dispatcher.registerRule(new SpawnSeekerRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            HasOwner(address(HAS_OWNER))
        ));
        dispatcher.registerRule(new MovementRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION))
        ));
        dispatcher.registerRule(new ScoutingRule(
            Seeker(address(SEEKER)),
            Seed(address(SEED)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            ProvidesEntropyTo(address(PROVIDES_ENTROPY_TO))
        ));
        dispatcher.registerRule(new HarvestRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            Resource(address(RESOURCE)),
            HasLocation(address(HAS_LOCATION)),
            HasResource(address(HAS_RESOURCE))
        ));
    }

}

