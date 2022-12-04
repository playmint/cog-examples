// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    Attribute,
    AttributeKind,
    State,
    NodeType,
    EdgeType,
    EdgeData,
    NodeTypeUtils,
    NodeIDUtils,
    NodeID
} from "cog/State.sol";

// ----------------------------------
// define some schema relationships
// ----------------------------------

contract HasOwner is EdgeType {
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("HAS_OWNER");
    }
}
contract HasLocation is EdgeType {
    function getCoords(State s, NodeID srcNodeID) public view returns (uint32 x, uint32 y) {
        NodeID id = s.getEdge(this, srcNodeID).nodeID;
        (,x,y) = NodeIDUtils.decodeID(id);
    }
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("HAS_LOCATION");
    }
}
contract HasResource is EdgeType {
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("HAS_RESOURCE");
    }
}
contract ProvidesEntropyTo is EdgeType {
    function getAttributes(NodeID /*id*/, uint /*idx*/) public pure returns (Attribute[] memory attrs) {
        attrs = new Attribute[](1);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("PROVIDES_ENTROPY_TO");
    }
}
