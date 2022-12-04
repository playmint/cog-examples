// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    Attribute,
    AttributeKind,
    State,
    NodeType,
    NodeData,
    NodeTypeUtils,
    NodeIDUtils,
    NodeID
} from "cog/State.sol";
import { Contents } from "../actions/Actions.sol";

contract Seed is NodeType {
    function ID(uint32 blk) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, blk);
    }
    function getAttributeValues(State s, NodeID id) public view returns (uint32 blk) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID id, NodeData /*data*/) public pure returns (uint32 blk) {
        (,, blk) = NodeIDUtils.decodeID(id);
        return blk;
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (uint32 blk) = getAttributeValues(id, data);
        attrs = new Attribute[](2);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("SEED");
        attrs[1].name = "block";
        attrs[1].kind = AttributeKind.UINT32;
        attrs[1].value = bytes32(uint(blk));
    }
}

contract Tile is NodeType {
    function ID(uint32 x, uint32 y) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, x, y);
    }
    function setAttributeValues(State s, NodeID id, Contents c) public returns (State) {
        return s.setNode(
            id,
            NodeData.wrap(uint256(c))
        );
    }
    function getAttributeValues(State s, NodeID id) public view returns (Contents c, uint32 x, uint32 y) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID id, NodeData data) public pure returns (Contents c, uint32 x, uint32 y) {
        (,x,y) = NodeIDUtils.decodeID(id);
        c = Contents(uint8(NodeData.unwrap(data)));
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (Contents c, uint32 x, uint32 y) = getAttributeValues(id, data);
        attrs = new Attribute[](4);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("TILE");
        attrs[1].name = "contents";
        attrs[1].kind = AttributeKind.UINT8;
        attrs[1].value = bytes32(uint(c));
        attrs[2].name = "x";
        attrs[2].kind = AttributeKind.UINT32;
        attrs[2].value = bytes32(uint(x));
        attrs[3].name = "y";
        attrs[3].kind = AttributeKind.UINT32;
        attrs[3].value = bytes32(uint(y));
    }
}

contract Resource is NodeType {
    enum Kind {
        UNKNOWN,
        CORN
    }
    function ID(Kind k) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, uint32(k));
    }
    function getAttributeValues(State s, NodeID id) public view returns (Kind k) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID id, NodeData /*data*/) public pure returns (Kind k) {
        (,, uint32 kid) = NodeIDUtils.decodeID(id);
        return Kind(kid);
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (Kind k) = getAttributeValues(id, data);
        attrs = new Attribute[](2);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("RESOURCE");
        attrs[1].name = "resource";
        attrs[1].kind = AttributeKind.UINT8;
        attrs[1].value = bytes32(uint(k));
    }
}

contract Seeker is NodeType {
    function ID(uint32 id) public view returns (NodeID) {
        return NodeTypeUtils.ID(this, uint32(id));
    }
    function setAttributeValues(State s, NodeID id, uint8 str) public returns (State) {
        return s.setNode(
            id,
            NodeData.wrap(uint256(str))
        );
    }
    function getAttributeValues(State s, NodeID id) public view returns (uint8 str) {
        return getAttributeValues(id, s.getNode(id));
    }
    function getAttributeValues(NodeID /*id*/, NodeData data) public pure returns (uint8 str) {
        str = uint8(NodeData.unwrap(data));
    }
    function getAttributes(State s, NodeID id) public view returns (Attribute[] memory attrs) {
        return getAttributes(id, s.getNode(id));
    }
    function getAttributes(NodeID id, NodeData data) public pure returns (Attribute[] memory attrs) {
        (,, uint32 sid) = NodeIDUtils.decodeID(id);
        (uint8 str) = getAttributeValues(id, data);
        attrs = new Attribute[](3);
        attrs[0].name = "kind";
        attrs[0].kind = AttributeKind.STRING;
        attrs[0].value = bytes32("SEEKER");
        attrs[1].name = "strength";
        attrs[1].kind = AttributeKind.UINT8;
        attrs[1].value = bytes32(uint(str));
        attrs[2].name = "sid";
        attrs[2].kind = AttributeKind.UINT32;
        attrs[2].value = bytes32(uint(sid));
    }
}

