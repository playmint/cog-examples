// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {
    State,
    NodeType,
    EdgeType,
    EdgeData,
    NodeTypeUtils,
    EdgeTypeUtils,
    NodeIDUtils,
    NodeID
} from "cog/State.sol";
import {
    Action,
    Rule,
    ActionTypeDef
} from "cog/Dispatcher.sol";
import {StateGraph} from "cog/StateGraph.sol";

import {
    CornSeekers,
    MoveSeeker,
    SpawnSeeker,
    ResetMap,
    Seeker,
    Resource,
    Tile,
    RevealSeed,
    ResetRule,
    SpawnSeekerRule,
    MovementRule,
    ScoutingRule,
    HarvestRule,
    Seed,
    HasOwner,
    HasLocation,
    HasResource,
    ProvidesEntropyTo
} from "../src/CornSeekers.sol";

using EdgeTypeUtils for EdgeType;

contract CornSeekersTest is Test {

    State internal g;
    CornSeekers internal game;

    // actions
    ResetMap internal RESET_MAP;
    RevealSeed internal REVEAL_SEED;
    MoveSeeker internal MOVE_SEEKER;
    SpawnSeeker internal SPAWN_SEEKER;

    // nodes
    Seeker internal SEEKER;
    Seed internal SEED;
    Tile internal TILE;
    Resource internal RESOURCE;

    // edges
    EdgeType internal PROVIDES_ENTROPY_TO;
    EdgeType internal HAS_OWNER;
    EdgeType internal HAS_LOCATION;
    EdgeType internal HAS_RESOURCE;

    // rules
    ResetRule internal RESET_RULE;
    MovementRule internal MOVEMENT_RULE;

    // accounts
    address aliceAccount;

    function setUp() public {

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
        PROVIDES_ENTROPY_TO = new ProvidesEntropyTo();
        HAS_OWNER = new HasOwner();
        HAS_LOCATION = new HasLocation();
        HAS_OWNER = new HasOwner();
        HAS_RESOURCE = new HasResource();

        // setup rules
        Rule[] memory rules = new Rule[](5);
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

        // setup state
        g = new StateGraph();

        // setup game
        game = new CornSeekers(g, rules);

        // setup users
        uint256 alicePrivateKey = 0xA11CE;
        aliceAccount = vm.addr(alicePrivateKey);

        // reset map before all tests
        Action memory reset = Action({
            owner: aliceAccount,
            id: address(RESET_MAP),
            args: "",
            block: block.number
        });
        console.log("RESET_MAP start");
        game.dispatch(reset);
        console.log("RESET_MAP done");
    }

    function testGetActionID() public {
        address id = game.getActionID("RESET_MAP");
        assertEq(
            id,
            address(RESET_MAP)
        );
    }

    function testHarvesting() public {
        // moving a seeker onto a CORN tile harvests the corn
        // this converts the tile to a GRASS tile and increases
        // the HAS_RESOURCE balance on the seeker

        // spawn a seeker bottom left corner of map
        Action memory spawnSeeker = Action({
            owner: aliceAccount,
            id: address(SPAWN_SEEKER),
            args: abi.encode(
                uint32(1),
                uint8(0),  // x
                uint8(0),  // y
                uint8(100) // str
            ),
            block: block.number
        });
        console.log("SPAWN_SEEKER start");
        game.dispatch(spawnSeeker);
        console.log("SPAWN_SEEKER end");

        // comfirm seeker is at tile (0,0)
        assertNodeEq(
            g.getEdge(HAS_LOCATION.ID(), SEEKER.ID(1)).nodeID,
            TILE.ID(0,0)
        );

        // confirm our current corn balance is 0
        assertEq(
            g.getEdge(HAS_RESOURCE.ID(), SEEKER.ID(1)).weight,
            0
        );

        // hack in CORN at tile (1,1) to bypass scouting
        TILE.setAttributeValues(
            g,
            TILE.ID(1,1),
            Tile.Contents.CORN
        );

        // move the seeker NORTHEAST to tile (1,1)
        Action memory moveSeeker = Action({
            owner: aliceAccount,
            id: address(MOVE_SEEKER),
            args: MOVE_SEEKER.encode(
                SEEKER.ID(1),
                MoveSeeker.Direction.NORTHEAST
            ),
            block: block.number
        });
        console.log("MOVE_SEEKER start");
        game.dispatch(moveSeeker);
        console.log("MOVE_SEEKER end");

        // comfirm seeker is now at tile (1,1)
        assertNodeEq(
            g.getEdge(HAS_LOCATION.ID(), SEEKER.ID(1)).nodeID,
            TILE.ID(1,1)
        );

        // confirm our corn balance is now 1
        assertEq(
            g.getEdge(HAS_RESOURCE.ID(), SEEKER.ID(1)).weight,
            1
        );

    }

    function testScouting() public {
        // scouting is in two parts because it requires
        // some randomness.
        //
        // the first part occurs during a MOVE_SEEKER or SPAWN_SEEKER
        // action which requests a SEED for any surrounding tiles
        //
        // a seed request is an edge from a SEED node pointing to
        // a TILE node.
        //
        // later a REVEAL_SEED request will submit the required
        // entopy and perform any followup processing
        //

        // spawn a seeker bottom left corner of map
        Action memory spawnSeeker = Action({
            owner: aliceAccount,
            id: address(SPAWN_SEEKER),
            args: abi.encode(
                uint32(1),
                uint8(0),  // x
                uint8(0),  // y
                uint8(100) // str
            ),
            block: block.number
        });
        console.log("SPAWN_SEEKER start");
        game.dispatch(spawnSeeker);
        console.log("SPAWN_SEEKER end");

        // there should be a seeker with a strength value
        uint8 str = SEEKER.getAttributeValues(g, SEEKER.ID(1));
        assertEq(
            str,
            100
        );

        // the seeker should have location
        assertNodeEq(
            g.getEdge(HAS_LOCATION.ID(), SEEKER.ID(1)).nodeID,
            TILE.ID(0,0)
        );

        // there should now be 1 PROVIDES_ENTROPY_TO edges
        // since the outter edge of the map is auto discovered
        // and since we start in a corner, so there shoiuld be
        // 1 UNDISCOVERED adjancent tile
        EdgeData[] memory pendingTiles = g.getEdges(
            PROVIDES_ENTROPY_TO.ID(),
            SEED.ID(uint32(block.number))
        );
        assertEq(pendingTiles.length, 1);

        // the pending tile should be UNDISCOVERED
        (Tile.Contents pendingContent,,) = TILE.getAttributeValues(
            g,
            pendingTiles[0].nodeID
        );
        assertEq(
            uint(pendingContent),
            uint(Tile.Contents.UNDISCOVERED)
        );

        // wait until the blockhash is revealed
        vm.roll(block.number + 1);

        // once we know the blockhash of the requested
        // seed, we can submit REVEAL_SEED action
        // to resolve it
        Action memory reveal1 = Action({
            owner: aliceAccount,
            id: address(REVEAL_SEED),
            args: REVEAL_SEED.encode(
                SEED.ID(uint32(block.number - 1)),
                uint32(uint(blockhash(block.number-1)))
            ),
            block: block.number
        });
        console.log("REVEAL_SEED1 start");
        game.dispatch(reveal1);
        console.log("REVEAL_SEED1 end");

        // The pendingTile should now be discovered
        (Tile.Contents discoveredContent,,) = TILE.getAttributeValues(
            g,
            pendingTiles[0].nodeID
        );
        assertGt(
            uint(discoveredContent),
            uint(Tile.Contents.UNDISCOVERED)
        );

        // move the seeker NORTHEAST
        Action memory moveSeeker = Action({
            owner: aliceAccount,
            id: address(MOVE_SEEKER),
            args: MOVE_SEEKER.encode(
                SEEKER.ID(1),
                MoveSeeker.Direction.NORTHEAST
            ),
            block: block.number
        });
        console.log("MOVE_SEEKER1 start");
        game.dispatch(moveSeeker);
        console.log("MOVE_SEEKER1 end");

        // seeker should now have location at 1,1
        assertNodeEq(
            g.getEdge(HAS_LOCATION.ID(), SEEKER.ID(1)).nodeID,
            TILE.ID(1,1)
        );

        // there should be three pending tiles now at (1,2) (2,2) (2,1)
        pendingTiles = g.getEdges(
            PROVIDES_ENTROPY_TO.ID(),
            SEED.ID(uint32(block.number))
        );
        assertEq(pendingTiles.length, 3);

        // attempting to move NORTHEAST again should be
        // a noop as the tile at (2,2) is UNDISCOVERED so it is
        // an illegal move. We don't error on such moves, we just
        // ignore them.
        console.log("MOVE_SEEKER2 start");
        game.dispatch(moveSeeker);
        console.log("MOVE_SEEKER2 end");
        assertNodeEq(
            g.getEdge(HAS_LOCATION.ID(), SEEKER.ID(1)).nodeID,
            TILE.ID(1,1)
        );

        // roll time forward
        vm.roll(block.number + 1);

        // submit the reveal action
        Action memory reveal2 = Action({
            owner: aliceAccount,
            id: address(REVEAL_SEED),
            args: REVEAL_SEED.encode(
                SEED.ID(uint32(block.number - 1)),
                uint32(uint(blockhash(block.number-1)))
            ),
            block: block.number
        });
        console.log("REVEAL_SEED2 start");
        game.dispatch(reveal2);
        console.log("REVEAL_SEED2 end");

        // the tiles should now all be revealed
        for (uint i=0; i<pendingTiles.length; i++) {
            (pendingContent,,) = TILE.getAttributeValues(
                g,
                pendingTiles[i].nodeID
            );
            assertGt(
                uint(pendingContent),
                uint(Tile.Contents.UNDISCOVERED)
            );
        }

        console.log("done");

    }

    function assertNodeEq(NodeID a, NodeID b) internal {
        assertEq(
            NodeID.unwrap(a),
            NodeID.unwrap(b)
        );
    }

}
