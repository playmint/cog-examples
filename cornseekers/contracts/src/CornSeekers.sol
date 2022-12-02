// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    Attribute,
    AttributeKind,
    State,
    NodeData,
    EdgeType,
    EdgeData,
    EdgeTypeID,
    EdgeTypeUtils,
    NodeType,
    NodeIDUtils,
    NodeTypeID,
    NodeTypeUtils,
    NodeID
} from "cog/State.sol";
import {
    Action,
    ActionType,
    ActionTypeDef,
    ActionArgDef,
    ActionArgKind,
    Rule,
    BaseDispatcher
} from "cog/Dispatcher.sol";

import {StateGraph} from "cog/StateGraph.sol";

// ----------------------------------
// define some actions
// ----------------------------------

contract ResetMap is ActionType {
    function getTypeDef() external view returns (ActionTypeDef memory def) {
        def.name = "RESET_MAP";
        def.id = address(this);
    }
}

contract RevealSeed is ActionType {
    function encode(NodeID seedID, uint32 entropy) public pure returns (bytes memory) {
        return abi.encode(seedID, entropy);
    }
    function decode(bytes memory args) public pure returns (NodeID id, uint32 entropy) {
        return abi.decode(args, (NodeID, uint32));
    }
    function getTypeDef() external view returns (ActionTypeDef memory def) {
        def.name = "REVEAL_SEED";
        def.id = address(this);
        def.arg0.name = "seekerID";
        def.arg0.kind = ActionArgKind.NODEID;
        def.arg0.required = true;
        def.arg1.name = "entropy";
        def.arg1.required = true;
        def.arg1.kind = ActionArgKind.UINT32;
    }
}

contract SpawnSeeker is ActionType {
    function encode(uint32 sid, uint8 x, uint8 y, uint8 strength) public pure returns (bytes memory) {
        return abi.encode( sid, x, y, strength);
    }
    function decode(bytes memory args) public pure returns (uint32 id, uint8 x, uint8 y, uint8 strength) {
        return abi.decode(args, (uint32, uint8, uint8, uint8));
    }
    function getTypeDef() external view returns (ActionTypeDef memory def) {
        def.name = "SPAWN_SEEKER";
        def.id = address(this);
        def.arg0.name = "seekerID";
        def.arg0.required = true;
        def.arg0.kind = ActionArgKind.NODEID;
        def.arg1.name = "x";
        def.arg1.required = true;
        def.arg1.kind = ActionArgKind.UINT8;
        def.arg2.name = "y";
        def.arg2.required = true;
        def.arg2.kind = ActionArgKind.UINT8;
        def.arg3.name = "strength";
        def.arg3.required = true;
        def.arg3.kind = ActionArgKind.UINT8;
    }
}

contract MoveSeeker is ActionType {
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
    function encode(NodeID seekerID, Direction dir) public pure returns (bytes memory) {
        return abi.encode(seekerID, dir);
    }
    function decode(bytes memory args) public pure returns (NodeID id, Direction dir) {
        return abi.decode(args, (NodeID, Direction));
    }
    function getTypeDef() external view returns (ActionTypeDef memory def) {
        def.name = "MOVE_SEEKER";
        def.id = address(this);
        def.arg0.name = "seekerID";
        def.arg0.required = true;
        def.arg0.kind = ActionArgKind.NODEID;
        def.arg1.name = "direction";
        def.arg1.required = true;
        def.arg1.kind = ActionArgKind.ENUM;
    }
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
        NodeID id = s.getEdge(EdgeTypeID.wrap(address(this)), srcNodeID).nodeID;
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
    ResetMap RESET_MAP;

    using EdgeTypeUtils for EdgeType;

    constructor(
        Tile tileNodeTypeAddr,
        ResetMap resetGameActionTypeAddr
    ) {
        TILE = tileNodeTypeAddr;
        RESET_MAP = resetGameActionTypeAddr;
    }

    function reduce(State state, Action memory action) public returns (State) {
        if (action.id == address(RESET_MAP)) {
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

    function getActionTypeDefs() public view returns (ActionTypeDef[] memory defs) {
        defs = new ActionTypeDef[](1);
        defs[0] = RESET_MAP.getTypeDef();
        return defs;
    }

    // function getNodeTypeDefs() external view returns (NodeTypeDef[] memory defs) {
    //     defs = new NodeTypeDef[](3);
    //     defs[0] = TILE.getTypeDef();
    //     return defs;
    // }

}

contract SpawnSeekerRule is Rule {

    Seeker SEEKER;
    Tile TILE;
    SpawnSeeker SPAWN_SEEKER;
    HasLocation HAS_LOCATION;
    HasOwner HAS_OWNER;

    using EdgeTypeUtils for HasLocation;
    using EdgeTypeUtils for HasOwner;

    constructor(
        Seeker seekerNodeTypeAddr,
        Tile tileNodeTypeAddr,
        HasLocation hasLocationAddr,
        HasOwner hasOwnerAddr,
        SpawnSeeker spawnActionTypeAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        HAS_OWNER = hasOwnerAddr;
        SPAWN_SEEKER = spawnActionTypeAddr;
    }

    function reduce(State state, Action memory action) public returns (State) {
        if (action.id == address(SPAWN_SEEKER)) {
            (uint32 sid, uint8 x, uint8 y, uint8 str) = SPAWN_SEEKER.decode(action.args);
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
                HAS_OWNER.ID(),
                id,
                EdgeData({
                    nodeID: NodeTypeUtils.ID( NodeType(action.owner), 0, 0),
                    weight: 0
                })
            );
            // set location by pointing a HAS_LOCATION at the tile
            state = state.setEdge(
                HAS_LOCATION.ID(),
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

    function getActionTypeDefs() public view returns (ActionTypeDef[] memory defs) {
        defs = new ActionTypeDef[](1);
        defs[0] = SPAWN_SEEKER.getTypeDef();
        return defs;
    }

    // function getNodeTypeDefs() external view returns (NodeTypeDef[] memory defs) {
    //     defs = new NodeTypeDef[](3);
    //     defs[0] = SEEKER.getTypeDef();
    //     defs[1] = TILE.getTypeDef();
    //     return defs;
    // }

}

contract MovementRule is Rule {

    Seeker SEEKER;
    Tile TILE;
    MoveSeeker MOVE_SEEKER;
    HasLocation HAS_LOCATION;

    using EdgeTypeUtils for HasLocation;

    constructor(
        Seeker seekerNodeTypeAddr,
        Tile tileNodeTypeAddr,
        HasLocation hasLocationAddr,
        MoveSeeker moveActionTypeAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        MOVE_SEEKER = moveActionTypeAddr;
    }

    function reduce(State state, Action memory action) public returns (State) {
        // movement is one tile at a time
        // you can only move onto an discovered tile
        if (action.id == address(MOVE_SEEKER)) {
            (NodeID seekerID, MoveSeeker.Direction dir) = MOVE_SEEKER.decode(action.args);
            (uint32 x, uint32 y) = HAS_LOCATION.getCoords(
                state,
                seekerID
            );
            int xx = int(uint(x));
            int yy = int(uint(y));
            if (dir == MoveSeeker.Direction.NORTH) {
                yy++;
            } else if (dir == MoveSeeker.Direction.NORTHEAST) {
                xx++;
                yy++;
            } else if (dir == MoveSeeker.Direction.EAST) {
                xx++;
            } else if (dir == MoveSeeker.Direction.SOUTHEAST) {
                xx++;
                yy--;
            } else if (dir == MoveSeeker.Direction.SOUTH) {
                yy--;
            } else if (dir == MoveSeeker.Direction.SOUTHWEST) {
                xx--;
                yy--;
            } else if (dir == MoveSeeker.Direction.WEST) {
                xx--;
            } else if (dir == MoveSeeker.Direction.NORTHWEST) {
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
                HAS_LOCATION.ID(),
                seekerID,
                EdgeData({
                    nodeID: targetTile,
                    weight: 0
                })
            );
        }
        return state;
    }

    function getActionTypeDefs() public view returns (ActionTypeDef[] memory defs) {
        defs = new ActionTypeDef[](1);
        defs[0] = MOVE_SEEKER.getTypeDef();
        return defs;
    }

    // function getNodeTypeDefs() external view returns (NodeTypeDef[] memory defs) {
    //     defs = new NodeTypeDef[](3);
    //     defs[0] = SEEKER.getTypeDef();
    //     defs[1] = TILE.getTypeDef();
    //     return defs;
    // }

}


contract ScoutingRule is Rule {

    Seeker SEEKER;
    Seed SEED;
    Tile TILE;
    SpawnSeeker SPAWN_SEEKER;
    MoveSeeker MOVE_SEEKER;
    HasLocation HAS_LOCATION;
    RevealSeed REVEAL_SEED;
    ProvidesEntropyTo PROVIDES_ENTROPY_TO;

    using EdgeTypeUtils for HasLocation;
    using EdgeTypeUtils for ProvidesEntropyTo;

    constructor(
        Seeker seekerNodeTypeAddr,
        Seed seedNodeTypeAddr,
        Tile tileNodeTypeAddr,
        HasLocation hasLocationAddr,
        RevealSeed revealSeedAddr,
        SpawnSeeker spawnActionTypeAddr,
        MoveSeeker moveActionTypeAddr,
        ProvidesEntropyTo providesEntropyEdgeAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        SEED = seedNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        REVEAL_SEED = revealSeedAddr;
        SPAWN_SEEKER = spawnActionTypeAddr;
        MOVE_SEEKER = moveActionTypeAddr;
        PROVIDES_ENTROPY_TO = providesEntropyEdgeAddr;
    }

    function reduce(State state, Action memory action) public returns (State) {
        // scouting tiles is performed in two stages
        // stage1: we commit to a SEED during a MOVE_SEEKER or SPAWN_SEEKER action
        // stage2: occurs when a REVEAL_SEED action is processed
        if (action.id == address(SPAWN_SEEKER)) {
            (, uint8 x, uint8 y,) = SPAWN_SEEKER.decode(action.args);
            state = commitAdjacent(state, action, int(uint(x)), int(uint(y)));
        } else if (action.id == address(MOVE_SEEKER)) {
            (NodeID seekerID,) = MOVE_SEEKER.decode(action.args);
            (uint32 x, uint32 y) = HAS_LOCATION.getCoords(state, seekerID);
            state = commitAdjacent(state, action, int(uint(x)), int(uint(y)));
        } else if (action.id == address(REVEAL_SEED)) {
            (NodeID seed, uint32 entropy) = REVEAL_SEED.decode(action.args);
            state = revealTiles(state, action, seed, entropy);
        }
        return state;
    }

    function commitAdjacent(State state, Action memory action, int x, int y) private returns (State) {
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
                    PROVIDES_ENTROPY_TO.ID(),
                    SEED.ID(uint32(action.block)),
                    EdgeData({
                        nodeID: tileID,
                        weight: 0
                    })
                );
            }
        }
        return state;
    }

    function revealTiles(State state, Action memory /*action*/, NodeID seedID, uint32 entropy) private returns (State) {
        EdgeData[] memory targetTiles = state.getEdges(
            PROVIDES_ENTROPY_TO.ID(),
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

    function getActionTypeDefs() public view returns (ActionTypeDef[] memory defs) {
        defs = new ActionTypeDef[](1);
        defs[0] = SPAWN_SEEKER.getTypeDef();
        return defs;
    }

    // function getNodeTypeDefs() external view returns (NodeTypeDef[] memory defs) {
    //     defs = new NodeTypeDef[](3);
    //     defs[0] = SEEKER.getTypeDef();
    //     defs[1] = TILE.getTypeDef();
    //     return defs;
    // }

}

contract HarvestRule is Rule {

    Seeker SEEKER;
    Tile TILE;
    Resource RESOURCE;
    MoveSeeker MOVE_SEEKER;
    HasLocation HAS_LOCATION;
    HasResource HAS_RESOURCE;

    using EdgeTypeUtils for HasLocation;
    using EdgeTypeUtils for HasResource;

    constructor(
        Seeker seekerNodeTypeAddr,
        Tile tileNodeTypeAddr,
        Resource resourceNodeTypeAddr,
        HasLocation hasLocationAddr,
        HasResource hasResourceAddr,
        MoveSeeker moveActionTypeAddr
    ) {
        SEEKER = seekerNodeTypeAddr;
        TILE = tileNodeTypeAddr;
        RESOURCE = resourceNodeTypeAddr;
        HAS_LOCATION = hasLocationAddr;
        HAS_RESOURCE = hasResourceAddr;
        MOVE_SEEKER = moveActionTypeAddr;
    }

    function reduce(State state, Action memory action) public returns (State) {
        // harvesting is triggered when you move to tile with CORN on it
        // standing on a CORN tile converts the tile to a GRASS tile
        // and increases the seeker's CORN balance in their STORAGE
        if (action.id == address(MOVE_SEEKER)) {
            (NodeID seekerID,) = MOVE_SEEKER.decode(action.args);
            (uint32 x, uint32 y) = HAS_LOCATION.getCoords(
                state,
                seekerID
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
                    HAS_RESOURCE.ID(),
                    seekerID
                ).weight;
                // increase the balance
                balance++;
                // store new balance
                state = state.setEdge(
                    HAS_RESOURCE.ID(),
                    seekerID,
                    EdgeData({
                        nodeID: RESOURCE.ID(Resource.Kind.CORN),
                        weight: balance
                    })
                );
            }

        }
        return state;
    }

    function getActionTypeDefs() public view returns (ActionTypeDef[] memory defs) {
        defs = new ActionTypeDef[](1);
        defs[0] = MOVE_SEEKER.getTypeDef();
        return defs;
    }

    // function getNodeTypeDefs() external view returns (NodeTypeDef[] memory defs) {
    //     defs = new NodeTypeDef[](3);
    //     defs[0] = SEEKER.getTypeDef();
    //     defs[1] = TILE.getTypeDef();
    //     defs[2] = RESOURCE.getTypeDef();
    //     return defs;
    // }

}


// ----------------------------------
// define a game as a set of rules
// ----------------------------------

contract CornSeekers is BaseDispatcher {

    constructor(State s, Rule[] memory rs) BaseDispatcher(s) {

        bool doStuff = false;
        if (rs.length == 0) {
            rs = setupDefaultRules();
            doStuff = true;
        }

        // assign all the given rules (this is hacky to allow from test)
        // TODO: we should be defining all the rules here not passing them in
        for (uint i=0; i<rs.length; i++) {
            registerRule(rs[i]);
        }

        // hacky dispatching so I have some data to play with
        // TODO: remove this
        if (doStuff) {
            dispatchSomeStuff();
        }
    }

    ResetMap RESET_MAP;
    RevealSeed REVEAL_SEED;
    MoveSeeker MOVE_SEEKER;
    SpawnSeeker SPAWN_SEEKER;
    Seeker SEEKER;
    Seed SEED;
    Tile TILE;
    Resource RESOURCE;

    function setupDefaultRules() public returns (Rule[] memory rules) {

        // setup actions
        RESET_MAP = new ResetMap();
        REVEAL_SEED = new RevealSeed();
        MOVE_SEEKER = new MoveSeeker();
        SPAWN_SEEKER = new SpawnSeeker();

        // setup nodes
        SEEKER = new Seeker();
        SEED = new Seed();
        TILE = new Tile();
        RESOURCE = new Resource();

        // setup edges
        ProvidesEntropyTo PROVIDES_ENTROPY_TO = new ProvidesEntropyTo();
        HasOwner HAS_OWNER = new HasOwner();
        HasLocation HAS_LOCATION = new HasLocation();
        HasResource HAS_RESOURCE = new HasResource();

        // setup rules
        rules = new Rule[](5);
        rules[0] = new ResetRule(
            Tile(address(TILE)),
            ResetMap(address(RESET_MAP))
        );
        rules[1] = new SpawnSeekerRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            HasOwner(address(HAS_OWNER)),
            SpawnSeeker(address(SPAWN_SEEKER))
        );
        rules[2] = new MovementRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            MoveSeeker(address(MOVE_SEEKER))
        );
        rules[3] = new ScoutingRule(
            Seeker(address(SEEKER)),
            Seed(address(SEED)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            RevealSeed(address(REVEAL_SEED)),
            SpawnSeeker(address(SPAWN_SEEKER)),
            MoveSeeker(address(MOVE_SEEKER)),
            ProvidesEntropyTo(address(PROVIDES_ENTROPY_TO))
        );
        rules[4] = new HarvestRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            Resource(address(RESOURCE)),
            HasLocation(address(HAS_LOCATION)),
            HasResource(address(HAS_RESOURCE)),
            MoveSeeker(address(MOVE_SEEKER))
        );
        return rules;
    }

    function dispatchSomeStuff() public {
        // reset map
        dispatch(Action({
            owner: msg.sender,
            id: address(RESET_MAP),
            args: "",
            block: block.number
        }));

        // spawn a blokey
        dispatch(Action({
            owner: msg.sender,
            id: address(SPAWN_SEEKER),
            args: abi.encode(
                uint32(1),
                uint8(0),  // x
                uint8(0),  // y
                uint8(100) // str
            ),
            block: block.number
        }));

        // move the blokey
        dispatch(Action({
            owner: msg.sender,
            id: address(MOVE_SEEKER),
            args: abi.encode(
                uint32(1),
                MoveSeeker.Direction.NORTHEAST
            ),
            block: block.number
        }));
    }

    function dispatch(Action memory action) public {
        // do any custom action validation/authorization here
        // ...
        // call _dispatch to send action through the registered rules
        _dispatch(action);
    }
}

