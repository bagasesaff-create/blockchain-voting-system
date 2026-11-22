

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Voting {

    // =====================================
    // 1. DATA STRUCTURES
    // =====================================

    address public owner;

    struct Election {
        string name;
        uint256 startTime;
        uint256 endTime;
        bool started;
        bool ended;
        uint256 totalVotes;
    }

    struct Candidate {
        uint256 id;
        string name;
        string description;
        uint256 voteCount;
    }

    // =====================================
    // 2. STATE VARIABLES
    // =====================================

    uint256 public electionCount;

    mapping(uint256 => Election) public elections;

    mapping(uint256 => Candidate[]) private candidates;

    mapping(uint256 => mapping(address => bool))
        public registeredVoters;

    mapping(uint256 => mapping(address => bool))
        public hasVoted;

    // =====================================
    // 3. EVENTS
    // =====================================

    event ElectionCreated(
        uint256 indexed electionId,
        string name
    );

    event CandidateAdded(
        uint256 indexed electionId,
        uint256 candidateId,
        string name
    );

    event VoterRegistered(
        uint256 indexed electionId,
        address voter
    );

    event ElectionStarted(uint256 indexed electionId);

    event ElectionEnded(uint256 indexed electionId);

    event VoteCast(
        uint256 indexed electionId,
        uint256 candidateId,
        address indexed voter
    );

    // =====================================
    // 4. MODIFIERS
    // =====================================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can execute");
        _;
    }

    modifier electionExists(uint256 electionId) {
        require(
            electionId > 0 && electionId <= electionCount,
            "Election does not exist"
        );
        _;
    }

    // =====================================
    // 5. CONSTRUCTOR
    // =====================================

    constructor() {
        owner = msg.sender;
    }

    // =====================================
    // 6. CREATE ELECTION
    // =====================================

    function createElection(
        string memory electionName,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner {

        require(bytes(electionName).length > 0, "Name required");
        require(startTime > block.timestamp, "Start must be future");
        require(endTime > startTime, "Invalid election period");

        electionCount++;

        elections[electionCount] = Election({
            name: electionName,
            startTime: startTime,
            endTime: endTime,
            started: false,
            ended: false,
            totalVotes: 0
        });

        emit ElectionCreated(electionCount, electionName);
    }

    // =====================================
    // 7. ADD CANDIDATE
    // =====================================

    function addCandidate(
        uint256 electionId,
        string memory candidateName,
        string memory description
    )
        external
        onlyOwner
        electionExists(electionId)
    {
        Election storage election = elections[electionId];

        require(!election.started, "Election already started");
        require(!election.ended, "Election already ended");
        require(bytes(candidateName).length > 0, "Name required");

        uint256 candidateId = candidates[electionId].length;

        candidates[electionId].push(
            Candidate({
                id: candidateId,
                name: candidateName,
                description: description,
                voteCount: 0
            })
        );

        emit CandidateAdded(
            electionId,
            candidateId,
            candidateName
        );
    }

    // =====================================
    // 8. REGISTER VOTER
    // =====================================

    function removeCandidate(
    uint256 electionId,
    uint256 candidateId
)
    external
    onlyOwner
    electionExists(electionId)
{
    Election storage election = elections[electionId];

    require(!election.started, "Election already started");
    require(
        candidateId < candidates[electionId].length,
        "Invalid candidate"
    );

    uint256 lastIndex = candidates[electionId].length - 1;

    candidates[electionId][candidateId] =
        candidates[electionId][lastIndex];

    candidates[electionId].pop();
}

    function registerVoter(
        uint256 electionId,
        address voter
    )
        external
        onlyOwner
        electionExists(electionId)
    {
        Election storage election = elections[electionId];

        require(!election.started, "Election already started");
        require(voter != address(0), "Invalid wallet");
        require(
            !registeredVoters[electionId][voter],
            "Voter already registered"
        );

        registeredVoters[electionId][voter] = true;

        emit VoterRegistered(electionId, voter);
    }

    // =====================================
    // 9. START ELECTION
    // =====================================

    function startElection(uint256 electionId)
        external
        onlyOwner
        electionExists(electionId)
    {
        Election storage election = elections[electionId];

        require(!election.started, "Already started");
        require(!election.ended, "Already ended");
        require(block.timestamp >= election.startTime, "Too early");
        require(block.timestamp <= election.endTime, "Period expired");
        require(candidates[electionId].length > 0, "No candidates");

        election.started = true;

        emit ElectionStarted(electionId);
    }

    // =====================================
    // 10. CAST VOTE
    // =====================================

    function vote(
        uint256 electionId,
        uint256 candidateId
    )
        external
        electionExists(electionId)
    {
        Election storage election = elections[electionId];

        require(election.started, "Election not started");
        require(!election.ended, "Election ended");
        require(block.timestamp <= election.endTime, "Voting period expired");

        require(
            registeredVoters[electionId][msg.sender],
            "Not registered"
        );

        require(
            !hasVoted[electionId][msg.sender],
            "Already voted"
        );

        require(
            candidateId < candidates[electionId].length,
            "Invalid candidate"
        );

        hasVoted[electionId][msg.sender] = true;

        candidates[electionId][candidateId].voteCount++;

        election.totalVotes++;

        emit VoteCast(electionId, candidateId, msg.sender);
    }

    // =====================================
    // 11. END ELECTION
    // =====================================

    function endElection(uint256 electionId)
        external
        onlyOwner
        electionExists(electionId)
    {
        Election storage election = elections[electionId];

        require(election.started, "Election not started");
        require(!election.ended, "Already ended");

        require(
            block.timestamp > election.endTime,
            "Election period not finished"
        );

        election.ended = true;

        emit ElectionEnded(electionId);
    }

    // =====================================
    // 12. GET CANDIDATES
    // =====================================

    function getCandidates(uint256 electionId)
        external
        view
        electionExists(electionId)
        returns (Candidate[] memory)
    {
        return candidates[electionId];
    }

    // =====================================
    // 13. GET RESULTS
    // =====================================

    function getResults(uint256 electionId)
        external
        view
        electionExists(electionId)
        returns (Candidate[] memory, uint256)
    {
        return (
            candidates[electionId],
            elections[electionId].totalVotes
        );
    }
}
