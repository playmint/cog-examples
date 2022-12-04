// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    Game,
    BasicGame
} from "cog/Game.sol";

import { HarvestRule } from "./rules/HarvestRule.sol";
import { ScoutingRule } from "./rules/ScoutingRule.sol";
import { ResetRule } from "./rules/ResetRule.sol";
import { MovementRule } from "./rules/MovementRule.sol";
import { SpawnSeekerRule } from "./rules/SpawnSeekerRule.sol";

import { Seeker, Seed, Tile, Resource } from "./schema/Nodes.sol";
import { ProvidesEntropyTo, HasOwner, HasLocation, HasResource } from "./schema/Edges.sol";

// -----------------------------------------------
// a Game sets up the State, Dispatcher and Router
//
// it sets up the rules our game uses and exposes
// the Game interface for discovery by cog-services
//
// we are using BasicGame to handle the boilerplate
// so all we need to do here is call registerRule()
// -----------------------------------------------

contract CornSeekers is Game, BasicGame {

    // node type refs
    Seeker public SEEKER;
    Seed public SEED;
    Tile public TILE;
    Resource public RESOURCE;

    // edge refs
    ProvidesEntropyTo public PROVIDES_ENTROPY_TO;
    HasOwner public HAS_OWNER;
    HasLocation public HAS_LOCATION;
    HasResource public HAS_RESOURCE;

    constructor() BasicGame("CORNSEEKERS") {
        // setup node types
        SEEKER = new Seeker();
        SEED = new Seed();
        TILE = new Tile();
        RESOURCE = new Resource();

        // setup edge types
        PROVIDES_ENTROPY_TO = new ProvidesEntropyTo();
        HAS_OWNER = new HasOwner();
        HAS_LOCATION = new HasLocation();
        HAS_RESOURCE = new HasResource();

        // setup rules
        dispatcher.registerRule(new ResetRule(
            Tile(address(TILE))
        ));
        dispatcher.registerRule(new SpawnSeekerRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            HasOwner(address(HAS_OWNER))
        ));
        dispatcher.registerRule(new MovementRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION))
        ));
        dispatcher.registerRule(new ScoutingRule(
            Seeker(address(SEEKER)),
            Seed(address(SEED)),
            Tile(address(TILE)),
            HasLocation(address(HAS_LOCATION)),
            ProvidesEntropyTo(address(PROVIDES_ENTROPY_TO))
        ));
        dispatcher.registerRule(new HarvestRule(
            Seeker(address(SEEKER)),
            Tile(address(TILE)),
            Resource(address(RESOURCE)),
            HasLocation(address(HAS_LOCATION)),
            HasResource(address(HAS_RESOURCE))
        ));
    }

}
