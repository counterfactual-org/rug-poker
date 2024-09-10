const fs = require("fs")
const { execSync } = require('child_process');

function mergeAbis(name, facets) {
    let abis = [];
    facets.forEach(facet => {
        getAbi(facet).forEach(abi => {
            if (abi.name === "selectors") return;
            if (abi.type === "function" && abis.find(a => a.type === "function" && a.name === abi.name)) {
                throw new Error("function with same name found: " + abi.name);
            }
            abis.push(abi);
        });
    });

    if (!fs.existsSync("abis")) {
        fs.mkdirSync("abis");
    }
    writeAbi(name, abis)
}

function getAbi(name) {
    return JSON.parse(execSync(`forge inspect ${name} abi`).toString())
}

function writeAbi(name, abi) {
    fs.writeFileSync(`abis/${name}.json`, JSON.stringify(abi, null, 2));
}

writeAbi("AuctionHouse", getAbi("AuctionHouse"))
writeAbi("NFT", getAbi("NFT"))
mergeAbis("NFTMinter", ["ClaimsFacet", "JackpotFacet", "MinterConfigsFacet", "MintFacet"]);
mergeAbis("Game", ["AttacksFacet", "CardsFacet", "GameConfigsFacet", "ItemsFacet", "PlayersFacet", "RandomizerFacet"]);
