// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { State, NodeID, EdgeData } from "cog/State.sol";
import { Context, Rule } from "cog/Dispatcher.sol";
import { Seeker, Tile } from "src/schema/Nodes.sol";
import { ProvidesEntropyTo, HasLocation } from "src/schema/Edges.sol";
import { Actions, Direction, Contents } from "src/actions/Actions.sol";

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
            (Contents c,,) = TILE.getAttributeValues(
                state,
                targetTile
            );
            if (c == Contents.UNDISCOVERED) {
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

