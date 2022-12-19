// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    State,
    EdgeData,
    Attr
} from "cog/State.sol";

interface Rel {
    function Owner() external;
    function Location() external;
    function Balance() external;
    function Biome() external;
    function Strength() external;
    function ProvidesEntropyTo() external;
}

interface Kind {
    function Seed() external;
    function Tile() external;
    function Resource() external;
    function Seeker() external;
}

enum ResourceKind {
    UNKNOWN,
    CORN
}

enum BiomeKind {
    UNDISCOVERED,
    BLOCKER,
    GRASS,
    CORN
}

library Node {
    function Seeker(uint64 id) internal pure returns (bytes12) {
        return bytes12(abi.encodePacked(Kind.Seeker.selector, id));
    }
    function Tile(uint32 x, uint32 y) internal pure returns (bytes12) {
        return bytes12(abi.encodePacked(Kind.Tile.selector, x, y));
    }
    function Resource(ResourceKind rk) internal pure returns (bytes12) {
        return bytes12(abi.encodePacked(Kind.Resource.selector, uint64(rk)));
    }
    function Seed(uint32 blk) internal pure returns (bytes12) {
        return bytes12(abi.encodePacked(Kind.Seed.selector, uint64(blk)));
    }
}

using Schema for State;

library Schema {

    function setLocation(State state, bytes12 node, bytes12 locationNode) internal {
        return state.set(Rel.Location.selector, 0x0, node, locationNode, uint160(0));
    }

    function getLocation(State state, bytes12 node) internal view returns (bytes12) {
        (bytes12 tile,) = state.get(Rel.Location.selector, 0x0, node);
        return tile;
    }

    function getLocationCoords(State state, bytes12 node) internal view returns (uint32 x, uint32 y) {
        bytes12 tile = getLocation(state, node);
        x = uint32(uint96(tile) >> 32);
        y = uint32(uint96(tile));
    }

    function setBiome(State state, bytes12 node, BiomeKind biome) internal {
        return state.set(Rel.Biome.selector, 0x0, node, Attr.UInt(), uint160(biome));
    }

    function getBiome(State state, bytes12 node) internal view returns (BiomeKind) {
        (,uint160 biome) = state.get(Rel.Biome.selector, 0x0, node);
        return BiomeKind(uint8(biome));
    }

    function setResourceBalance(State state, bytes12 node, ResourceKind rk, uint32 balance) internal {
        return state.set(Rel.Balance.selector, uint8(rk), node, Node.Resource(rk), uint160(balance));
    }

    function getResourceBalance(State state, bytes12 node, ResourceKind rk) internal view returns (uint32) {
        (,uint160 balance) = state.get(Rel.Balance.selector, uint8(rk), node);
        return uint32(balance);
    }

    function setOwner(State state, bytes12 node, bytes12 ownerNode) internal {
        return state.set(Rel.Owner.selector, 0x0, node, ownerNode, uint160(0));
    }

    function setOwner(State state, bytes12 node, address ownerAddr) internal {
        return state.set(Rel.Owner.selector, 0x0, node, Attr.Address(), uint160(ownerAddr));
    }

    function getOwner(State state, bytes12 node) internal view returns (bytes12, uint160) {
        return state.get(Rel.Owner.selector, 0x0, node);
    }

    function getOwnerAddress(State state, bytes12 ownerNode) internal view returns (address) {
        uint160 ownerAddr;
        while (ownerAddr == 0) {
            (ownerNode, ownerAddr) = state.getOwner(ownerNode);
        }
        return address(ownerAddr);
    }

    function setStrength(State state, bytes12 node, uint64 v) internal {
        return state.set(Rel.Strength.selector, 0x0, node, Attr.Int(), uint160(v));
    }

    function getStrength(State state, bytes12 node) internal view returns (uint64) {
        (,uint160 str) = state.get(Rel.Strength.selector, 0x0, node);
        return uint64(str);
    }

    function setEntropyCommitment(State state, uint32 blk, bytes12 node) internal {
        // we will treat the key as an idx and iterate to find a free slot
        // this is not a very effceient solution, but is a direct port from
        // how it worked before with appendEdge
        for (uint8 key=0; key<256; key++) {
            (bytes12 dstNodeID,) = state.get(Rel.ProvidesEntropyTo.selector, key, Node.Seed(blk));
            if (dstNodeID == bytes12(0)) {
                return state.set(Rel.ProvidesEntropyTo.selector, key, Node.Seed(blk), node, uint160(0));
            }
        }
        revert("too many edges");
    }

    function getEntropyCommitments(State state, uint32 blk) internal view returns (bytes12[] memory) {
        // we will treat the key as an idx and iterate to find a free slot
        // this is not a very effceient solution, but is a direct port from
        // how it worked before with appendEdge
        bytes12[100] memory foundNodes;
        uint8 i;
        for (i=0; i<256; i++) {
            (foundNodes[i],) = state.get(Rel.ProvidesEntropyTo.selector, i, Node.Seed(blk));
            if (foundNodes[i] == bytes12(0)) {
                break;
            }
        }
        bytes12[] memory nodes = new bytes12[](i);
        for (uint8 j=0; j<i; j++) {
            nodes[j] = foundNodes[j];
        }
        return nodes;
    }

}
