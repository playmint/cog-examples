import Phaser from 'phaser';
import { ApolloClient, NormalizedCacheObject, InMemoryCache, gql, split, HttpLink, FetchResult } from '@apollo/client';
import { getMainDefinition } from '@apollo/client/utilities';
import { createClient } from "graphql-ws";
import { GraphQLWsLink } from "@apollo/client/link/subscriptions";
import { BigNumber } from "ethers";
import * as ethers from "ethers";

// TODO
//
// * [x] load tilemapCSV from chain
// * [x] dispatch MOVE_SEEKER actions on keypress
// * [x] highlight tile of seeker and move with movement
// * [x] subscribe to state changes
// * [x] show corn balance
// * [x] reset button
// * [x] clear session button
// * [x] spawn button
// * [x] multiplayer

const STATE_FRAGMENT = `
    block
    tiles: nodes(match: {kinds: ["Tile"]}) {
        coords: keys
        biome: value(match: {via: [{rel: "Biome"}]})
        seed: node(match: {kinds: ["Seed"], via: [{rel: "ProvidesEntropyTo", dir: IN}]}) {
          key
        }
    }
    seekers: nodes(match: {kinds: ["Seeker"]}) {
        key
        position: node(match: {kinds: ["Tile"], via:[{rel: "Location"}]}) {
            coords: keys
        }
        player: node(match: {kinds: ["Player"], via:[{rel: "Owner"}]}) {
            address: key
        }
        cornBalance: value(match: {via: [{rel: "Balance"}]})
    }
`;

const STATE_SUBSCRIPTION = gql(`
    subscription OnState {
        state(gameID: "latest") {
            ${STATE_FRAGMENT}
        }
    }
`);

const STATE_QUERY = gql(`
    query GetState {
        game(id: "latest") {
            state {
                ${STATE_FRAGMENT}
            }
        }
    }
`);

const DISPATCH = gql(`
    mutation dispatch($gameID: ID!, $action: String!, $auth: String!) {
        dispatch(
            gameID: $gameID,
            action: $action,        # encoded action bytes
            authorization: $auth    # session's signature of $action
        ) {
            id
            status
        }
    }
`);

const SIGNIN = gql(`
    mutation signin($gameID: ID!, $session: String!, $auth: String!) {
        signin(
            gameID: $gameID,
            session: $session,
            ttl: 1000,
            scope: "0xffffffff",
            authorization: $auth,
        )
    }
`);

const actions = new ethers.utils.Interface([
    "function RESET_MAP() external",
    "function REVEAL_SEED(uint32 blk, uint32 entropy) external",
    "function SPAWN_SEEKER(uint32 sid, uint8 x, uint8 y, uint8 str) external",
    "function MOVE_SEEKER(uint32 sid, uint8 dir) external",
]);

enum BiomeKind {
    UNDISCOVERED,
    BLOCKER,
    GRASS,
    CORN
}

enum Direction {
    NORTH,
    NORTHEAST,
    EAST,
    SOUTHEAST,
    SOUTH,
    SOUTHWEST,
    WEST,
    NORTHWEST
}

export default class Demo extends Phaser.Scene {

    constructor() {
        super('GameScene');
    }

    preload() {
        this.load.image('tiles', 'assets/roguelikeSheet_transparent.png');
        this.load.spritesheet('chars', 'assets/roguelikeChar_transparent.png', {frameWidth: 16, frameHeight: 16, spacing: 1});
    }

    async create() {
        // which game
        const gameID = "latest";
        const scene = this;

        // setup the client
        const httpLink = new HttpLink({
            uri: 'http://localhost:8080/query'
        });
        const wsLink = new GraphQLWsLink(
            createClient({
                url: "ws://localhost:8080/query",
            }),
        );
        const link = split(
            ({ query }) => {
                const definition = getMainDefinition(query);
                return (
                    definition.kind === 'OperationDefinition' &&
                    definition.operation === 'subscription'
                );
            },
            wsLink,
            httpLink,
        );
        const client = new ApolloClient({
            link,
            uri: 'http://localhost:8080/query',
            cache: new InMemoryCache(),
        });


        // setup wallet providers etc
        const provider = new ethers.providers.Web3Provider((window as any).ethereum)
        const owner = provider.getSigner();
        await provider.send("eth_requestAccounts", [])
        const ownerAddr = await owner.getAddress();
        if (localStorage.getItem('ownerAddr') != ownerAddr) {
            localStorage.clear();
            localStorage.setItem('ownerAddr', ownerAddr);
        }

        // setup short lived session key and save in localstorage
        let session: ethers.Wallet;
        let sessionKey = localStorage.getItem('sessionKey');
        if (sessionKey) {
            session = new ethers.Wallet(sessionKey);
            console.log('using session key from localstorage', session.privateKey);
        } else {
            session = ethers.Wallet.createRandom();
            sessionKey = session.privateKey;
            // build signin mutation
            const signin = async () => {
                const msg = ethers.utils.concat([
                    ethers.utils.toUtf8Bytes(`You are signing in with session: `),
                    ethers.utils.getAddress(session.address),
                ]);
                const auth = await owner.signMessage(msg);
                return client.mutate({mutation: SIGNIN, variables: {gameID, auth, session: session.address}});
            }
            // signin with metamask, sign the session key, and save the key for later if success
            await signin();
            localStorage.setItem('sessionKey', ethers.utils.hexlify(session.privateKey));
        }

        // keep track of seeker owners/sprites
        const seekers:any = {};
        const getPlayerSeeker = () => {
            for (let k in seekers) {
                if (seekers[k].owner == ownerAddr) {
                    return k;
                }
            }
            return null;
        }

        // setup dispatch mutation
        const dispatch = async (actionName:string, ...actionArgs:any):Promise<any> => {
            console.log('dispatching', actionName, actionArgs);
            const action = actions.encodeFunctionData(actionName, actionArgs);
            const actionDigest = ethers.utils.arrayify(ethers.utils.keccak256(action));
            const auth = await session.signMessage(actionDigest);
            return client.mutate({mutation: DISPATCH, variables: {gameID, auth, action}})
                .then(() => console.log('dispatched', actionName))
                .catch((err) => console.log('dispatch fail:', err));
        }

        // plonk dispatch on window so we can call it from the console
        (window as any).dispatch = dispatch;

        // init the map
        const data = Array(32).fill(Array(48).fill(7));
        const map = scene.make.tilemap({ data, tileWidth: 16, tileHeight: 16, width: 64, height: 64 });
        const landTiles = map.addTilesetImage('tiles', undefined, 16, 16, 0, 1);
        const baseLayer = map.createBlankLayer('base', landTiles, 0, 0);
        const resourcesLayer = map.createBlankLayer('resources', landTiles, 0, 0);

        // UI
        const playerBalance = this.add.text(600, 200, '', { fontFamily: 'system', color: '#000000' });
        const help = this.add.text(600, 400, 'use WASD to move', { fontFamily: 'system', color: '#000000', fontSize: '11px' });
        const buttonStyle = {
            fontFamily: 'system',
            color: '#efefef',
            backgroundColor: '#555555',
            padding: {x: 5, y: 5},
        };
        const resetButton = this.add.text(600, 10, 'RESET MAP', buttonStyle)
            .setInteractive()
            .on('pointerup', () => {
                // reset the map
                dispatch('RESET_MAP')
            });
        const signoutButton = this.add.text(600, 40, 'CLEAR SESSION', buttonStyle)
            .setInteractive()
            .on('pointerup', () => {
                // reset the map
                localStorage.clear();
                (window as any).location.reload();
            });
        const spawnButton = this.add.text(600, 70, 'SPAWN SEEKER', buttonStyle)
            .setInteractive()
            .on('pointerup', () => {
                if (getPlayerSeeker()) {
                    console.log('you already have a seeker');
                    return;
                }
                // spawn a seeker at a random location along the top edge
                dispatch('SPAWN_SEEKER', Object.keys(seekers).length+2, Math.floor(Math.random()*32), 0, 1)
            });

        // highlight the selected seeker
        // and allow moving the hightlight like a cursor that eventully
        // snaps back to the real location
        const marker = this.add.graphics()
            .lineStyle(1, 0xFFFFFF, 0.3)
            .strokeRect(0, 0, map.tileWidth, map.tileHeight);
        let markerRealPos = [0,0];
        let lastMoveAt = Date.now()-1000;
        const updateMarker = () => {
            const timeSinceLastMove = Date.now() - lastMoveAt;
            if (timeSinceLastMove < 500) {
                return;
            }
            marker.x = markerRealPos[0];
            marker.y = markerRealPos[1];
        }
        setInterval(updateMarker, 3000);

        // keep track of things we are trying to reveal
        const revealing = {} as any;

        // helper to check if a coord is "near" the player selection
        const isNearPlayer = (x:number,y:number):boolean => {
            return Math.abs(x - (marker.x/map.tileWidth)) < 4 && Math.abs(y - (marker.y/map.tileHeight)) < 4;
        }

        // helper to map biomes to tile map index
        const biomeToIdx = (i:number, seed:number): number => {
            switch (i) {
                case null: return 1;
                case BiomeKind.UNDISCOVERED: return 6;
                case BiomeKind.BLOCKER: return 64;
                case BiomeKind.GRASS: return [5, 62, 66][seed % 3];
                case BiomeKind.CORN: return 5;
                default: throw new Error(`unknown kind=${i}`);
            }
        }

        // helper to map a seeker id to a char sprite
        const charIdx = (key:string): number => {
            const id = BigNumber.from(key).toNumber();
            return id % 14;
        }

        // this is the main update loop which fires each time a
        // the subscription gets an update of the world state
        const onStateChange = (state: any) => {
            console.log(state);
            if (!state) {
                return;
            }

            // draw the map
            state.tiles.forEach((tile: any) => {
                const x = BigNumber.from(tile.coords[0]).toNumber();
                const y = BigNumber.from(tile.coords[1]).toNumber();
                const blk = BigNumber.from(tile.seed?.key || 0).toNumber();
                const biomeIdx = biomeToIdx(tile.biome, blk);
                map.putTileAt(biomeIdx, x, y, undefined, baseLayer);
                if (tile.biome === BiomeKind.CORN) {
                    map.putTileAt(15, x, y, undefined, resourcesLayer);
                } else {
                    map.removeTileAt(x, y, undefined, undefined, resourcesLayer);
                }
                // resolve any nearby pending tiles that needs resolving
                if (tile.seed && tile.biome == BiomeKind.UNDISCOVERED && isNearPlayer(x,y)) {
                    // generate some randomness ... obvisouly letting the
                    // client decide random is bad - this is just a toy
                    const entropy = Math.floor(Math.random()*1000);
                    if (!revealing[blk]) {
                        revealing[blk] = true;
                        dispatch("REVEAL_SEED", blk, entropy)
                            .catch((err) => console.error(`REVEAL_SEED ${blk} ${entropy} fail`, err));
                    }
                }
            });

            state.seekers.forEach((seeker: any) => {
                // position the seekers
                const x = BigNumber.from(seeker.position.coords[0]).toNumber();
                const y = BigNumber.from(seeker.position.coords[1]).toNumber();
                if (!seekers[seeker.key]) {
                    seekers[seeker.key] = {
                        sprite: scene.add.image(16,16,'chars', charIdx(seeker.key)),
                        owner: ethers.utils.getAddress(seeker.player.address),
                    };
                }
                const {sprite,owner} = seekers[seeker.key];
                const isPlayerSeeker = owner == ownerAddr;
                sprite.x = 16*x+8;
                sprite.y = 16*y+8;
                // update player
                if (isPlayerSeeker) {
                    // score
                    playerBalance.setText(`CORN: ${seeker.cornBalance}`);
                    // highlight the player's seeker
                    markerRealPos = [16*x,16*y];
                    updateMarker();
                }
            });

        }

        // helper to check if a tile is passable
        const isBlocker = (idx:number):boolean => {
            if (idx === 6 || idx === 64 || idx === 0) {
                return true;
            }
            return false;
        };

        //  dispatch MOVE_SEEKER on WASD movement
        const move = (dir: Direction) => async () => {
            const id = getPlayerSeeker();
            if (!id) {
                console.log('you have no seeker or not connected metamask');
                return;
            }
            lastMoveAt = Date.now();
            // check we don't try and move onto a blocker
            // optimistically move the cursor - to make it feel like it's done something
            let tile;
            switch (dir) {
                case Direction.NORTH:
                    tile = baseLayer.getTileAtWorldXY(marker.x, marker.y+16, true);
                    if (isBlocker(tile.index)) {
                        console.log('bumped into a wall');
                        return;
                    }
                    marker.y += 16;
                    break;
                case Direction.SOUTH:
                    tile = baseLayer.getTileAtWorldXY(marker.x, marker.y-16, true);
                    if (isBlocker(tile.index)) {
                        console.log('bumped into a wall');
                        return;
                    }
                    marker.y -= 16;
                    break;
                case Direction.EAST:
                    tile = baseLayer.getTileAtWorldXY(marker.x+16, marker.y, true);
                    if (isBlocker(tile.index)) {
                        console.log('bumped into a wall');
                        return;
                    }
                    marker.x += 16;
                    break;
                case Direction.WEST:
                    tile = baseLayer.getTileAtWorldXY(marker.x-16, marker.y, true);
                    if (isBlocker(tile.index)) {
                        console.log('bumped into a wall');
                        return;
                    }
                    marker.x -= 16;
                    break;
            }
            await dispatch("MOVE_SEEKER", id, dir);
        }
        scene.input.keyboard.on('keydown-A', move(Direction.WEST));
        scene.input.keyboard.on('keydown-D', move(Direction.EAST));
        scene.input.keyboard.on('keydown-W', move(Direction.SOUTH));
        scene.input.keyboard.on('keydown-S', move(Direction.NORTH));

        // subscribe to future state changes
        client.subscribe({
            query: STATE_SUBSCRIPTION,
        }).subscribe(
            (result) => onStateChange(result.data.state),
            (err) => console.error('subscriptionError', err),
            () => console.warn('subscriptionClosed')
        )

        // fetch initial state
        await client.query({query: STATE_QUERY})
            .then((result) => onStateChange(result.data.game.state))
            .catch((err) => console.error('err', err));
        updateMarker();

    }

}
