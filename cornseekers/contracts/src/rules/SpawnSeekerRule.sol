// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { State, NodeData, NodeID, NodeTypeUtils, EdgeData, NodeType } from "cog/State.sol";
import { Context, Rule } from "cog/Dispatcher.sol";
import { Seeker, Tile } from "src/schema/Nodes.sol";
import { HasLocation, HasOwner } from "src/schema/Edges.sol";
import { Actions, Contents } from "src/actions/Actions.sol";

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

    function getInitialContents(uint8 x, uint8 y) private pure returns (Contents) {
        if (x == 0 || y == 0 || x == 31 || y == 31) { // grass around the edge
            return Contents.GRASS;
        } else { // everything else unknown
            return Contents.UNDISCOVERED;
        }
    }

    function getInitialNodeData(uint8 x, uint8 y) private pure returns (NodeData) {
        return NodeData.wrap(uint256(getInitialContents(x, y)));
    }

}

