// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { State, NodeData } from "cog/State.sol";
import { Context, Rule } from "cog/Dispatcher.sol";
import { Tile } from "src/schema/Nodes.sol";
import { Actions, Contents } from "src/actions/Actions.sol";

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
