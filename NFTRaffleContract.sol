// SPDX-License-Identifier: MIT

// Created by Ransika of Szeeta blockchain solutions

pragma solidity ^0.8.2;

import "node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// *******************************************************************************************
//  Use this smart contract to assign random winners safely while minting

//        this contact can safely assign random winner using the chainlink VRF
//        refer the https://docs.chain.link for more information
//        this is not an audited contract, creator is not responsible for any activities
// 
// If you found this useful
// Buy me a coffee: 0x15Cf49f835C5545810a2CCd4c8F71B17dc16aE22
// *******************************************************************************************

contract NFTRaffleContract is ERC721, ERC721Enumerable, VRFConsumerBase {
    using Strings for uint256;

    address public admin;

    string public base;

    uint256 public maxSupply = 1000;
    uint256 public mintCounter = 1; //token counter
    uint256 public unitPrice; //price per token
    uint256 public prizeMoney; // to keeo track of the prize money
    uint256 public prizePerWinner;
    uint256 public maxMintsPerAddress;
    
    uint256 internal toAdd;
    uint256 internal randomNo;
    uint256 internal factor;
    uint256 internal numberOfWinners;


    bytes32 internal keyHash;
    bytes32 internal request;

    bool public paused;

    uint256[] internal winners;

    mapping(uint256 => bool) internal didWin;
    mapping(uint256 => bool) internal didWithdraw;

    constructor(
        address vrfCo, //VRF cordinator address for the network
        address link, //link token address for the network
        uint unitPrice_,
        uint maxMintsPerAddress_,
        uint numberOfWinners_,
        uint prizePerWinner_,
        bytes32 keyhash_, //VRF public keyhash for the network
        string memory collectionName,
        string memory collectionSymbol
        
    )
        ERC721(collectionName, collectionSymbol)
            VRFConsumerBase(vrfCo,link)
    {
        unitPrice = unitPrice_;
        keyHash = keyhash_;
        admin = msg.sender;
        maxMintsPerAddress = maxMintsPerAddress_;
        factor = maxSupply/numberOfWinners_;
        numberOfWinners = numberOfWinners_;
        prizePerWinner=prizePerWinner_;

    }
    // modifiers

    modifier onlyOwner(){
        require (msg.sender == admin);
        _;
    }
    modifier notPaused(){
        require(!paused);
        _;
    }

    //events

    event winnerAdded(address winner, uint256 token);
    event addWinner();
    event stateChanged(bool state);

    // public & external

    function mint(uint256 amount, address reciever) public payable notPaused{

        require(amount <= maxMintsPerAddress && (mintCounter + amount) <= maxSupply && msg.value == unitPrice * amount);
        for (uint256 i; i < amount; i++) {
            _safeMint(reciever, mintCounter);

            if (mintCounter % factor == 0) {
                prizeMoney += prizePerWinner;
                toAdd +=1;
                emit addWinner();
            }
            if (mintCounter == maxSupply && winners.length != numberOfWinners){
                toAdd ++;
                emit addWinner();
            }
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return string(abi.encodePacked(base, tokenId.toString(), ".json"));
    }

    function walletOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }
    
    function getWinners() external view returns(uint256[] memory){
        return winners;
    }

    function withdrawPrize(uint256 id) external notPaused{
        require(didWin[id] && !didWithdraw[id]);
        require(msg.sender == ownerOf(id));

        didWithdraw[id] = true;
        prizeMoney -= prizePerWinner;
        (bool success, ) = payable(msg.sender).call{value: prizePerWinner}("");
        require(success, "Transfer Failed");
    }

    //external restricted

    //getting random number from chainlink oracle and assingning a unique winner.

    //assignnig of winner is seperated because chainlink does not retunrn the random value instantly
    // therefore it's seperated into 3 funtions to get, view and assing
    //you can automate this process using the addWinner event or openzeppalin defender

    function getRandomNumber() external onlyOwner returns (bytes32 requestId) {
        uint256 fee = 0.0001 * 1 ether; // this fixed fee varies with the network
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function viewRandom() external view onlyOwner returns(uint256 num){
        return randomNo;
    }

    function AssignWinner() external onlyOwner notPaused{
        require(toAdd>0);
        require(randomNo != 0 && didWin[randomNo]);
        toAdd -= 1;
        didWin[randomNo] = true;
        winners.push(randomNo);
        emit winnerAdded(ownerOf(randomNo), randomNo);
    }

    function changeState() external onlyOwner {
        bool prevState = paused;
        paused = !prevState;
        emit stateChanged(!prevState);
    }

    function transferOwnership(address newOwner) external onlyOwner notPaused{
        admin = newOwner;
    }

    function withdraw() external onlyOwner notPaused{

        require(address(this).balance > prizeMoney);

        uint256 withdrawableAmount = address(this).balance - prizeMoney;

        (bool success, ) = payable(admin).call{value: withdrawableAmount}("");
        require(success, "Transfer Failed");
    }

    //internal

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomNo = (randomness & factor) +1;
        request = requestId;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
