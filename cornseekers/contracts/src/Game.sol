// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BasicGame } from "cog/Game.sol";

import { HarvestRule } from "src/rules/HarvestRule.sol";
import { ScoutingRule } from "src/rules/ScoutingRule.sol";
import { ResetRule } from "src/rules/ResetRule.sol";
import { MovementRule } from "src/rules/MovementRule.sol";
import { SpawnSeekerRule } from "src/rules/SpawnSeekerRule.sol";

import { SessionRouter } from "cog/SessionRouter.sol";
import { Actions } from "src/actions/Actions.sol";

// -----------------------------------------------
// a Game sets up the State, Dispatcher and Router
//
// it sets up the rules our game uses and exposes
// the Game interface for discovery by cog-services
//
// we are using BasicGame to handle the boilerplate
// so all we need to do here is call registerRule()
// -----------------------------------------------

contract Game is BasicGame {

    constructor() BasicGame("CORNSEEKERS") {
        // setup rules
        dispatcher.registerRule(new ResetRule());
        dispatcher.registerRule(new SpawnSeekerRule());
        dispatcher.registerRule(new MovementRule());
        dispatcher.registerRule(new ScoutingRule());
        dispatcher.registerRule(new HarvestRule());

        // TODO: REMOVE THESE - I'm just playing with the services
        // dispatcher.dispatch(
        //     abi.encodeCall(Actions.RESET_MAP, ())
        // );
        // SessionRouter(address(router)).authorizeAddr(dispatcher, 0, 0xffffffff, address(0x1));
    }

}
