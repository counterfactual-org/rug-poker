// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibString } from "solmate/utils/LibString.sol";
import { Base64 } from "src/libraries/Base64.sol";

struct TokenAttr {
    TokenAttrType _type;
    string traitType;
    string value;
}

enum TokenAttrType {
    Number,
    String
}

library TokenURILib {
    using LibString for uint256;

    function uri(string memory name, string memory description, string memory image, TokenAttr[] memory attrs)
        internal
        pure
        returns (string memory)
    {
        string memory dataURI =
            string.concat('{"name":"', name, '","description":"', description, '","image":"', image, '","attributes":[');
        for (uint256 i; i < attrs.length; ++i) {
            if (i > 0) {
                dataURI = string.concat(dataURI, ",");
            }
            TokenAttr memory attr = attrs[i];
            string memory value = attr._type == TokenAttrType.String ? string.concat('"', attr.value, '"') : attr.value;
            dataURI = string.concat(dataURI, string.concat('{"trait_type":"', attr.traitType, '","value":', value, "}"));
        }
        dataURI = string.concat(dataURI, "]}");
        return string.concat("data:application/json;base64,", Base64.encode(bytes(dataURI)));
    }
}
