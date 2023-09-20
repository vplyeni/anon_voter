// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VoterContract is Ownable{

    address public keyHolder;


    event VotingStarted(uint16 indexed voteId, string topic);

    event VotingEnded(uint16 indexed voteId, string topic, uint32 voted, uint32 result);


    event ProposalStarted(uint16 indexed proposalId, string topic);

    event ProposalEnded(uint16 indexed proposalId, string topic, uint32 voted, uint32 result);


    enum VotingType {
        Closed,
        YesNo,
        OneToTen
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

    struct Proposal {
        uint16 id;
        string topic;
        uint32 voted;
        uint32 result;
        address proposer;
        uint256 blockNumberStarted;
        uint256 blockNumberWillNotEndBefore; 
        uint256 blockNumberClosed; 
        VotingType proposalType;
    }


    mapping(address=>bool) private __VOTERS__;

    mapping(uint16 => mapping(address => uint8)) private votePower;
    mapping(uint16 => Voting) public votings;

    mapping(uint16 => mapping(address => uint8)) private proposalVotePower;
    mapping(uint16 => Proposal) public proposals;


    uint8 private constant minBlockDuration = 1;

    uint16 public voteId = 0;
    uint16 public proposalId = 0;

    uint16 public  totalVoterCount = 0;


    modifier noEmptyString(string memory str){
        require(bytes(str).length > 0);
        _;
    }
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
    modifier onlyNotVotedVoters(uint16 id){
        require(__VOTERS__[msg.sender],"You are not a voter");
        require(votePower[id][msg.sender]==0,"You have voted before");
        _;
    }
    modifier onlyNotVotedVotersForProposal(uint16 id){
        require(__VOTERS__[msg.sender],"You are not a voter");
        require(proposalVotePower[id][msg.sender]==0,"You have voted before");
        _;
    }
    modifier isVotingContinuing(uint16 id) {
        require(votings[id].votingType!=VotingType.Closed,"There is no voting");
        _;
    }
    modifier isVotingEnded(uint16 id) {
        require(votings[id].votingType==VotingType.Closed,"Current voting is not ended yet.");
        _;
    }
    modifier isProposalContinuing(uint16 id) {
        require(proposals[id].proposalType!=VotingType.Closed,"There is no voting");
        _;
    }
    modifier isProposalEnded(uint16 id) {
        require(proposals[id].proposalType==VotingType.Closed,"Current voting is not ended yet.");
        _;
    }

    //INITIATION OF CONTRACT

    function setKeyHolderAddress(address adr) external onlyOwner{
        keyHolder = adr;
    }

    //

    function giveVotingPower(address voterAddress) external onlyKeyHolder noZeroAddress(voterAddress) {
        require(!__VOTERS__[voterAddress],"Given address is already a voter.");
        totalVoterCount = totalVoterCount + 1;
        __VOTERS__[voterAddress] = true;
    }

    function openProposal(VotingType _proposalType ,string calldata _topic) public noEmptyString(_topic) onlyVoters(msg.sender){
        require(_proposalType != VotingType.Closed,"Proposal Type cannot be closed at initial state.");

        proposals[proposalId].id = proposalId;
        proposals[proposalId].topic = _topic;

        proposals[proposalId].voted = 0;
        proposals[proposalId].result = 0;

        proposals[proposalId].proposer = msg.sender;

        proposals[proposalId].blockNumberStarted = block.number;
        proposals[proposalId].blockNumberWillNotEndBefore = block.number + minBlockDuration;
        
        proposals[proposalId].blockNumberClosed = 0;

        proposals[proposalId].proposalType = _proposalType;

        proposalId += 1;
    }

    function closeProposal(uint16 id) public isProposalContinuing(id) onlyVoters(msg.sender){
        require(block.number>=proposals[id].blockNumberWillNotEndBefore,"Voting cannot be closed before it's designated to.");
        _closeProposal(id);
    }

    function closeVoting(uint16 id) public isVotingContinuing(id) onlyVoters(msg.sender) {
        require(block.number>=votings[id].blockNumberWillNotEndBefore,"Voting cannot be closed before it's designated to.");
        _closeVoting(id);
    }

    //Voting Functions For internal standardasation

    function _closeProposal(uint16 id) private {
        VotingType _votingType = proposals[id].proposalType;

        proposals[id].proposalType = VotingType.Closed;
        proposals[id].blockNumberClosed = block.number;

        _openVoting(id, _votingType);

        emit ProposalEnded(id, proposals[id].topic, proposals[id].voted, proposals[id].result);
    }


    function _openVoting(uint16 _proposalId, VotingType _votingType) private {
        require(_votingType != VotingType.Closed,"Voting Type cannot be closed at initial state.");
        
        votings[voteId].id = voteId;
        votings[voteId].proposer = proposals[_proposalId].proposer;

        votings[voteId].topic = proposals[_proposalId].topic;
        votings[voteId].blockNumberStarted = block.number;
        votings[voteId].blockNumberWillNotEndBefore = block.number + minBlockDuration;


        votings[voteId].result = 0;
        votings[voteId].voted = 0;

        votings[voteId].votingType = _votingType;

        voteId +=1;
        
        emit VotingStarted(voteId-1, proposals[_proposalId].topic);
    }

    function _closeVoting(uint16 id) private {
        votings[id].votingType = VotingType.Closed;
        votings[id].blockNumberClosed = block.number;

        emit VotingEnded(id, votings[id].topic, votings[id].voted, votings[id].result);
    }

    function useVotePowerYesNo(uint16 id,NoYes vote) external isVotingContinuing(id) onlyNotVotedVoters(id){
        require(votings[id].votingType==VotingType.YesNo,"Currently we are not voting on this function.");
        if(vote==NoYes.No){
            votePower[id][msg.sender] = 1;
            votings[id].result += 1;
        }else{
            votePower[id][msg.sender] = 10;
            votings[id].result += 10;
        }
        votings[id].voted += 1;
    }
    
    function useVotePowerOne2Ten(uint16 id,uint8 vote) external isVotingContinuing(id) onlyNotVotedVoters(id){
        require(vote>0&&vote<11,"Please vote between 1 to 10.");
        require(votings[id].votingType==VotingType.OneToTen,"Currently we are not voting on this function.");

        votePower[id][msg.sender] = vote;
        votings[id].result += vote;
        votings[id].voted += 1;
    }

    function useVotePowerProposalYesNo(uint16 id,NoYes vote) external isProposalContinuing(id) onlyNotVotedVotersForProposal(id){
        require(proposals[id].proposalType==VotingType.YesNo,"Currently we are not voting on this function.");

        if(vote==NoYes.No){
            proposalVotePower[id][msg.sender] = 1;
            proposals[id].result += 1;
        }else{
            proposalVotePower[id][msg.sender] = 10;
            proposals[id].result += 10;
        }
        proposals[id].voted += 1;
    }

    function useVotePowerProposalOne2Ten(uint16 id,uint8 vote) external isProposalContinuing(id) onlyNotVotedVotersForProposal(id){
        require(0<vote&&vote<11,"Please vote between 1 to 10.");
        require(proposals[id].proposalType==VotingType.OneToTen,"Currently we are not voting on this function.");

        proposalVotePower[id][msg.sender] = vote;
        
        proposals[id].result += vote;
        proposals[id].voted += 1;
    }

    function getVotings(uint8 skip, uint8 take) external view returns(Voting[] memory){
        Voting[] memory _votings = new Voting[](take);
        uint16 vi = voteId;

        if(skip>vi){
            return _votings;
        }else if(skip+take>vi){
            for (uint8 i = 1; i <= vi-skip; i++) 
            {
                _votings[i-1] = votings[vi-i];
            }
        }else{
            for (uint8 i = 1; i <= take; i++) 
            {
                _votings[i-1] = votings[vi-i];
            }
        }

        return _votings;
    }

    function getProposals(uint16 skip, uint16 take) external view returns(Proposal[] memory){
        Proposal[] memory _proposals = new Proposal[](take);
        uint16 pi = proposalId;

        if(skip>pi){
            return _proposals;
        }else if(skip+take>pi){
            for (uint16 i = 1; i <= pi-skip; i++) 
            {
                _proposals[i-1] = proposals[pi-i];
            }
        }else{
            for (uint16 i = 1; i <= take; i++) 
            {
                _proposals[i-1] = proposals[pi-i];
            }
        }

        return _proposals;
    }

    function whatDidIVote() external view returns(uint8){
        return votePower[voteId][msg.sender];
    }
    function amIVOTER() external view returns(bool){
        return __VOTERS__[msg.sender];
    }
}