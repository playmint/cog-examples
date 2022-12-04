// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { State, EdgeData, NodeID } from "cog/State.sol";
import { Context, Rule } from "cog/Dispatcher.sol";
import { Seeker, Seed, Tile } from "../schema/Nodes.sol";
import { HasLocation, ProvidesEntropyTo } from "../schema/Edges.sol";
import { Actions, Direction, Contents } from "../actions/Actions.sol";

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
            (Contents c,,) = TILE.getAttributeValues(
                state,
                tileID
            );
            if (c == Contents.UNDISCOVERED) {
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
            (Contents c, uint32 x, uint32 y) = TILE.getAttributeValues(
                state,
                targetTiles[i].nodeID
            );
            if (c != Contents.UNDISCOVERED) {
                continue;
            }
            uint8 r = random(entropy, x, y);
            if (r > 90) {
                c = Contents.CORN;
            } else {
                c = Contents.GRASS;
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

