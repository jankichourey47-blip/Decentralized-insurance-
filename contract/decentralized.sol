// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GigInsure
 * @dev Decentralized insurance pool for gig workers with peer-governed claims
 */
contract GigInsure {
    
    struct Member {
        uint256 totalContributions;
        uint256 lastContributionTime;
        bool isActive;
        uint256 claimCount;
    }
    
    struct Claim {
        address claimant;
        uint256 amount;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    mapping(address => Member) public members;
    mapping(uint256 => Claim) public claims;
    uint256 public claimCounter;
    uint256 public totalPoolBalance;
    uint256 public constant MINIMUM_CONTRIBUTION = 0.01 ether;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MAX_CLAIM_AMOUNT = 1 ether;
    
    event MemberJoined(address indexed member, uint256 contribution);
    event ContributionMade(address indexed member, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, address indexed claimant, uint256 amount);
    event VoteCast(uint256 indexed claimId, address indexed voter, bool support);
    event ClaimExecuted(uint256 indexed claimId, address indexed claimant, uint256 amount, bool approved);
    
    /**
     * @dev Join the insurance pool with initial contribution
     */
    function joinPool() external payable {
        require(msg.value >= MINIMUM_CONTRIBUTION, "Contribution below minimum");
        require(!members[msg.sender].isActive, "Already a member");
        
        members[msg.sender] = Member({
            totalContributions: msg.value,
            lastContributionTime: block.timestamp,
            isActive: true,
            claimCount: 0
        });
        
        totalPoolBalance += msg.value;
        
        emit MemberJoined(msg.sender, msg.value);
    }
    
    /**
     * @dev Submit a claim for insurance payout
     * @param amount The amount requested (must be <= MAX_CLAIM_AMOUNT)
     * @param description Reason for the claim
     */
    function submitClaim(uint256 amount, string calldata description) external {
        require(members[msg.sender].isActive, "Not an active member");
        require(amount <= MAX_CLAIM_AMOUNT, "Claim amount exceeds maximum");
        require(amount <= totalPoolBalance, "Insufficient pool balance");
        require(bytes(description).length > 0, "Description required");
        
        uint256 claimId = claimCounter++;
        Claim storage newClaim = claims[claimId];
        newClaim.claimant = msg.sender;
        newClaim.amount = amount;
        newClaim.description = description;
        newClaim.deadline = block.timestamp + VOTING_PERIOD;
        newClaim.executed = false;
        
        emit ClaimSubmitted(claimId, msg.sender, amount);
    }
    
    /**
     * @dev Vote on a pending claim
     * @param claimId The ID of the claim to vote on
     * @param support True to approve, false to reject
     */
    function voteOnClaim(uint256 claimId, bool support) external {
        require(members[msg.sender].isActive, "Not an active member");
        require(claimId < claimCounter, "Invalid claim ID");
        
        Claim storage claim = claims[claimId];
        require(!claim.executed, "Claim already executed");
        require(block.timestamp < claim.deadline, "Voting period ended");
        require(!claim.hasVoted[msg.sender], "Already voted");
        require(claim.claimant != msg.sender, "Cannot vote on own claim");
        
        claim.hasVoted[msg.sender] = true;
        
        if (support) {
            claim.votesFor++;
        } else {
            claim.votesAgainst++;
        }
        
        emit VoteCast(claimId, msg.sender, support);
    }
    
    /**
     * @dev Execute a claim after voting period ends
     * @param claimId The ID of the claim to execute
     */
    function executeClaim(uint256 claimId) external {
        require(claimId < claimCounter, "Invalid claim ID");
        
        Claim storage claim = claims[claimId];
        require(!claim.executed, "Claim already executed");
        require(block.timestamp >= claim.deadline, "Voting period not ended");
        
        claim.executed = true;
        bool approved = claim.votesFor > claim.votesAgainst;
        
        if (approved && claim.amount <= totalPoolBalance) {
            totalPoolBalance -= claim.amount;
            members[claim.claimant].claimCount++;
            payable(claim.claimant).transfer(claim.amount);
            
            emit ClaimExecuted(claimId, claim.claimant, claim.amount, true);
        } else {
            emit ClaimExecuted(claimId, claim.claimant, 0, false);
        }
    }
    
    /**
     * @dev Make additional contributions to the pool
     */
    function contribute() external payable {
        require(members[msg.sender].isActive, "Not an active member");
        require(msg.value > 0, "Contribution must be positive");
        
        members[msg.sender].totalContributions += msg.value;
        members[msg.sender].lastContributionTime = block.timestamp;
        totalPoolBalance += msg.value;
        
        emit ContributionMade(msg.sender, msg.value);
    }
    
    /**
     * @dev Get claim details
     */
    function getClaimDetails(uint256 claimId) external view returns (
        address claimant,
        uint256 amount,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline,
        bool executed
    ) {
        require(claimId < claimCounter, "Invalid claim ID");
        Claim storage claim = claims[claimId];
        return (
            claim.claimant,
            claim.amount,
            claim.description,
            claim.votesFor,
            claim.votesAgainst,
            claim.deadline,
            claim.executed
        );
    }
    
    /**
     * @dev Check if address has voted on a claim
     */
    function hasVotedOnClaim(uint256 claimId, address voter) external view returns (bool) {
        require(claimId < claimCounter, "Invalid claim ID");
        return claims[claimId].hasVoted[voter];
    }
}
