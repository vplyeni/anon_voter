// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VoterContract is Ownable{

    address public keyHolder;

    enum VotingType {
        Closed,
        YesNo,
        OneToTen,
        Proposal
    }
    enum NoYes {
        No,
        Yes
    }

    struct Voting {
        uint16 id;
        string topic;
        uint32 voted;
        uint32 result;
        address proposer;
        uint256 blockNumberStarted;
        uint256 blockNumberWillNotEndBefore; 
        uint256 blockNumberClosed; 
        VotingType votingType;
    }

    event VotingStarted(uint16 indexed voteId);

    event VotingEnded(uint16 indexed voteId, uint32 voted, uint32 result);
    
    uint8 private constant minBlockDuration = 1;

    uint16 public voteId = 0;

    mapping(address=>bool) private __VOTERS__;

    mapping(uint16 => mapping(address => uint8)) private votePower;
    mapping(uint16 => Voting) public votings;

    uint16 public  totalVoterCount = 0;

    modifier noZeroAddress(address adr){
        require(adr!=address(0),"Zero Address entered");
        _;
    }
    modifier onlyKeyHolder {
        require(msg.sender == keyHolder,"You are not the KeyHolderContract");
        _;
    }

    modifier onlyVoters(address adr){
        require(__VOTERS__[adr],"You are not a voterr");
        _;
    }
    modifier onlyNotVotedVoters{
        require(__VOTERS__[msg.sender],"You are not a voter");
        require(votePower[voteId][msg.sender]==0,"You have voted before");
        _;
    }

    modifier isVotingStarted {
        require(votings[voteId].votingType!=VotingType.Closed,"There is no voting");
        _;
    }
    modifier isVotingEnded {
        require(votings[voteId].votingType==VotingType.Closed,"Current voting is not ended yet.");
        _;
    }

    function setKeyHolderAddress(address adr) external onlyOwner{
        keyHolder = adr;
    }

    function giveVotingPower(address voterAddress) external onlyKeyHolder noZeroAddress(voterAddress) {
        require(!__VOTERS__[voterAddress],"Given address is already a voter.");
        totalVoterCount = totalVoterCount + 1;
        __VOTERS__[voterAddress] = true;
    }

    function openVoting(VotingType _votingType,uint256 _votingDurationBasedBlockNumber,string calldata _topic) external onlyOwner isVotingEnded {
        require(_votingType!=VotingType.Closed);

        votings[voteId].id = voteId;
        votings[voteId].proposer = msg.sender;

        votings[voteId].topic = _topic;
        votings[voteId].blockNumberStarted = block.number;
        votings[voteId].blockNumberWillNotEndBefore = block.number + _votingDurationBasedBlockNumber;


        votings[voteId].result = 0;
        votings[voteId].voted = 0;

        votings[voteId].votingType = _votingType;
        //EMIT
    }
    
    function openProposal(string memory _topic) external  onlyVoters(msg.sender) isVotingEnded {
        require(bytes(_topic).length != 0);
        
        votings[voteId].id = voteId;
        votings[voteId].proposer = msg.sender;
        
        votings[voteId].topic = _topic;
        votings[voteId].blockNumberStarted = block.number;
        votings[voteId].blockNumberWillNotEndBefore = block.number + minBlockDuration;

        votings[voteId].result = 10;
        votings[voteId].voted = 1;

        votePower[voteId][msg.sender] = 10;

        votings[voteId].votingType = VotingType.Proposal;

        emit VotingStarted(voteId);
    }
    
    function closeProposal() external onlyVoters(msg.sender){
        require(votings[voteId].votingType==VotingType.Proposal,"There is no voting or, it is not a proposal.");
        require(block.number>=votings[voteId].blockNumberWillNotEndBefore,"Even owner cannot end voting before it has designated to.");

        votings[voteId].votingType = VotingType.Closed;
        votings[voteId].blockNumberClosed=block.number;

        emit VotingEnded(voteId, votings[voteId].voted, votings[voteId].result);

        voteId += 1;

        if(votings[voteId-1].result*2>=totalVoterCount){
            votings[voteId].id = voteId;
            votings[voteId].proposer = votings[voteId-1].proposer;

            votings[voteId].topic = votings[voteId-1].topic;
            votings[voteId-1].topic = string(abi.encodePacked("Proposal: ",votings[voteId-1].topic));

            votings[voteId].blockNumberStarted = block.number;
            votings[voteId].blockNumberWillNotEndBefore = block.number + minBlockDuration*3;

            votings[voteId].result = 0;
            votings[voteId].voted = 0;

            votings[voteId].votingType = VotingType.YesNo;

            emit VotingStarted(voteId);
        }
    }

    function closeVoting() external onlyVoters(msg.sender) {
        require(block.number>=votings[voteId].blockNumberWillNotEndBefore,"Even owner cannot end voting before it has designated to.");
        require(votings[voteId].votingType!=VotingType.Closed&&votings[voteId].votingType!=VotingType.Proposal);
        _closeVoting();
    }

    function _closeVoting() private isVotingStarted {
        voteId +=1;
        votings[voteId-1].votingType = VotingType.Closed;
        votings[voteId-1].blockNumberClosed = block.number;
        //EMIT
    }

    function useVotePowerYesNo(NoYes vote) external isVotingStarted onlyNotVotedVoters{
        require(votings[voteId].votingType==VotingType.YesNo,"Currently we are not voting on this function.");
        if(vote==NoYes.No){
            votePower[voteId][msg.sender] = 1;
            votings[voteId].result += 1;
        }else{
            votePower[voteId][msg.sender] = 10;
            votings[voteId].result += 10;
        }
        votings[voteId].voted += 1;
    }
    
    function useVotePowerONE_TEN(uint8 vote) external isVotingStarted onlyNotVotedVoters{
        require(vote>0&&vote<11,"Please vote between 1 to 10.");
        require(votings[voteId].votingType==VotingType.OneToTen,"Currently we are not voting on this function.");

        votePower[voteId][msg.sender] = vote;
        votings[voteId].result += vote;
        votings[voteId].voted += 1;
    }

    function useVotePowerProposal(NoYes vote) external isVotingStarted onlyNotVotedVoters{
        require(votings[voteId].votingType==VotingType.Proposal,"Currently we are not voting on this function.");

        if(vote==NoYes.No){
            votePower[voteId][msg.sender] = 1;
            votings[voteId].result += 1;
        }else{
            votePower[voteId][msg.sender] = 10;
            votings[voteId].result += 10;
        }

        votings[voteId].voted += 1;
    }

    function getLastVotings(uint8 limit) external view returns(Voting[] memory){
        Voting[] memory _votings = new Voting[](limit);
        uint16 vi = voteId;
        
        if(vi>(limit-1)){
            if(bytes(votings[vi].topic).length>0){
                for (uint8 i = 0; i < limit; i++) 
                {
                    _votings[i] = votings[vi-i];
                }
            }else{
                for (uint8 i = 1; i < limit; i++) 
                {
                    _votings[i-1] = votings[vi-i];
                }
            }       
        }else{
            if(bytes(votings[vi].topic).length>0){
                for (uint8 i = 0; i <= vi; i++) 
                {
                    _votings[i] = votings[vi-i];
                }
            }else{
                for (uint8 i = 1; i <= vi; i++) 
                {
                    _votings[i-1] = votings[vi-i];
                }
            }
            
        }
        return _votings;
    }

    function whatDidIVote() external view returns(uint8){
        return votePower[voteId][msg.sender];
    }
    function amIVOTER() external view returns(bool){
        return __VOTERS__[msg.sender];
    }
}