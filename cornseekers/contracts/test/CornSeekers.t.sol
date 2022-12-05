// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { State, NodeID, EdgeData } from "cog/State.sol";

import { Game} from "src/Game.sol";
import { Actions, Direction, Contents } from "src/actions/Actions.sol";

contract CornSeekersTest is Test {

    Game internal game;
    State internal g;

    // accounts
    address aliceAccount;

    function setUp() public {
        // setup game
        game = new Game();

        // fetch the State to play with
        g = game.getState();

        // setup users
        uint256 alicePrivateKey = 0xA11CE;
        aliceAccount = vm.addr(alicePrivateKey);

        // reset map before all tests
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.RESET_MAP, ())
        );
    }

    function testHarvesting() public {
        // moving a seeker onto a CORN tile harvests the corn
        // this converts the tile to a GRASS tile and increases
        // the HAS_RESOURCE balance on the seeker

        // dispatch as alice
        vm.startPrank(aliceAccount);

        // spawn a seeker bottom left corner of map
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.SPAWN_SEEKER, (
                1,   // seeker id (sid)
                0,   // x
                0,   // y
                100  // strength attr
            ))
        );

        // comfirm seeker is at tile (0,0)
        assertNodeEq(
            g.getEdge( game.HAS_LOCATION(), game.SEEKER().ID(1)).nodeID,
            game.TILE().ID(0,0)
        );

        // confirm our current corn balance is 0
        assertEq(
            g.getEdge(game.HAS_RESOURCE(), game.SEEKER().ID(1)).weight,
            0
        );

        // hack in CORN at tile (1,1) to bypass scouting
        game.TILE().setAttributeValues(
            g,
            game.TILE().ID(1,1),
            Contents.CORN
        );

        // move the seeker NORTHEAST to tile (1,1)
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.MOVE_SEEKER, (
                1,                   // seeker id (sid)
                Direction.NORTHEAST  // direction to move
            ))
        );

        // comfirm seeker is now at tile (1,1)
        assertNodeEq(
            g.getEdge(game.HAS_LOCATION(), game.SEEKER().ID(1)).nodeID,
            game.TILE().ID(1,1)
        );

        // confirm our corn balance is now 1
        assertEq(
            g.getEdge(game.HAS_RESOURCE(), game.SEEKER().ID(1)).weight,
            1
        );

        // stop being alice
        vm.stopPrank();
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

        // dispatch as alice
        vm.startPrank(aliceAccount);

        // spawn a seeker bottom left corner of map
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.SPAWN_SEEKER, (
                1,   // seeker id (sid)
                0,   // x
                0,   // y
                100  // strength attr
            ))
        );

        // there should be a seeker with a strength value
        uint8 str = game.SEEKER().getAttributeValues(g, game.SEEKER().ID(1));
        assertEq(
            str,
            100
        );

        // the seeker should have location
        assertNodeEq(
            g.getEdge(game.HAS_LOCATION(), game.SEEKER().ID(1)).nodeID,
            game.TILE().ID(0,0)
        );

        // there should now be 1 PROVIDES_ENTROPY_TO edges
        // since the outter edge of the map is auto discovered
        // and since we start in a corner, so there shoiuld be
        // 1 UNDISCOVERED adjancent tile
        EdgeData[] memory pendingTiles = g.getEdges(
            game.PROVIDES_ENTROPY_TO(),
            game.SEED().ID(uint32(block.number))
        );
        assertEq(pendingTiles.length, 1);

        // the pending tile should be UNDISCOVERED
        (Contents pendingContent,,) = game.TILE().getAttributeValues(
            g,
            pendingTiles[0].nodeID
        );
        assertEq(
            uint(pendingContent),
            uint(Contents.UNDISCOVERED)
        );

        // wait until the blockhash is revealed
        vm.roll(block.number + 1);

        // once we know the blockhash of the requested
        // seed, we can submit REVEAL_SEED action
        // to resolve it
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.REVEAL_SEED, (
                game.SEED().ID(uint32(block.number - 1)),
                uint32(uint(blockhash(block.number-1)))
            ))
        );

        // The pendingTile should now be discovered
        (Contents discoveredContent,,) = game.TILE().getAttributeValues(
            g,
            pendingTiles[0].nodeID
        );
        assertGt(
            uint(discoveredContent),
            uint(Contents.UNDISCOVERED)
        );

        // move the seeker NORTHEAST
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.MOVE_SEEKER, (
                1,                   // seeker id (sid)
                Direction.NORTHEAST  // direction to move
            ))
        );

        // seeker should now have location at 1,1
        assertNodeEq(
            g.getEdge(game.HAS_LOCATION(), game.SEEKER().ID(1)).nodeID,
            game.TILE().ID(1,1)
        );

        // there should be three pending tiles now at (1,2) (2,2) (2,1)
        pendingTiles = g.getEdges(
            game.PROVIDES_ENTROPY_TO(),
            game.SEED().ID(uint32(block.number))
        );
        assertEq(pendingTiles.length, 3);

        // attempting to move NORTHEAST again should be
        // a noop as the tile at (2,2) is UNDISCOVERED so it is
        // an illegal move. We don't error on such moves, we just
        // ignore them.
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.MOVE_SEEKER, (
                1,                   // seeker id (sid)
                Direction.NORTHEAST  // direction to move
            ))
        );
        assertNodeEq(
            g.getEdge(game.HAS_LOCATION(), game.SEEKER().ID(1)).nodeID,
            game.TILE().ID(1,1)
        );

        // roll time forward
        vm.roll(block.number + 1);

        // submit the reveal action
        game.getDispatcher().dispatch(
            abi.encodeCall(Actions.REVEAL_SEED, (
                game.SEED().ID(uint32(block.number - 1)),
                uint32(uint(blockhash(block.number-1)))
            ))
        );

        // the tiles should now all be revealed
        for (uint i=0; i<pendingTiles.length; i++) {
            (pendingContent,,) = game.TILE().getAttributeValues(
                g,
                pendingTiles[i].nodeID
            );
            assertGt(
                uint(pendingContent),
                uint(Contents.UNDISCOVERED)
            );
        }


        // stop being alice
        vm.stopPrank();
    }

    function assertNodeEq(NodeID a, NodeID b) internal {
        assertEq(
            NodeID.unwrap(a),
            NodeID.unwrap(b)
        );
    }

}
