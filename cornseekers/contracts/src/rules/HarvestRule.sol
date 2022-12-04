// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { State, EdgeData, NodeID } from "cog/State.sol";
import { Context, Rule } from "cog/Dispatcher.sol";
import { Seeker, Tile, Resource } from "../schema/Nodes.sol";
import { HasLocation, HasResource } from "../schema/Edges.sol";
import { Actions, Direction, Contents } from "../actions/Actions.sol";


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
            (Contents c,,) = TILE.getAttributeValues(
                state,
                targetTile
            );
            if (c == Contents.CORN) {
                // convert tile to grass
                c = Contents.GRASS;
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

