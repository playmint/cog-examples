// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseGame } from "cog/Game.sol";
import { BaseDispatcher } from "cog/Dispatcher.sol";
import { SessionRouter } from "cog/SessionRouter.sol";
import { StateGraph } from "cog/StateGraph.sol";

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

contract Game is BaseGame {

    constructor() BaseGame("CORNSEEKERS") {
        // create a state
        StateGraph state = new StateGraph();

        // create a session router
        SessionRouter router = new SessionRouter();

        // configure our dispatcher with state, rules and trust the router
        BaseDispatcher dispatcher = new BaseDispatcher();
        dispatcher.registerState(state);
        dispatcher.registerRule(new ResetRule());
        dispatcher.registerRule(new SpawnSeekerRule());
        dispatcher.registerRule(new MovementRule());
        dispatcher.registerRule(new ScoutingRule());
        dispatcher.registerRule(new HarvestRule());
        dispatcher.registerRouter(router);

        // update the game with this config
        _registerState(state);
        _registerRouter(router);
        _registerDispatcher(dispatcher);

        // playing...
        // TODO: REMOVE THESE - I'm just playing with the services
        // dispatcher.dispatch(
        //     abi.encodeCall(Actions.RESET_MAP, ())
        // );
        // SessionRouter(address(router)).authorizeAddr(dispatcher, 0, 0xffffffff, address(0x1));
    }

}
