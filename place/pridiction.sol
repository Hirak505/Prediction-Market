// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PredictionMarket
 * @dev A decentralized prediction market smart contract
 */
contract PredictionMarket {
    address public owner;
    uint256 public marketCounter;
    
    struct Market {
        uint256 id;
        string question;
        uint256 endTime;
        bool resolved;
        bool outcome; // true = YES, false = NO
        uint256 totalYesBets;
        uint256 totalNoBets;
        address creator;
    }
    
    struct Bet {
        address bettor;
        uint256 amount;
        bool prediction; // true = YES, false = NO
        bool claimed;
    }
    
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Bet)) public bets;
    mapping(uint256 => address[]) public marketBettors;
    
    event MarketCreated(uint256 indexed marketId, string question, uint256 endTime, address creator);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, uint256 amount, bool prediction);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event WinningsWithdrawn(uint256 indexed marketId, address indexed bettor, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier marketExists(uint256 _marketId) {
        require(_marketId > 0 && _marketId <= marketCounter, "Market does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        marketCounter = 0;
    }
    
    /**
     * @dev Creates a new prediction market
     * @param _question The question for the prediction market
     * @param _duration Duration of the market in seconds
     */
    function createMarket(string memory _question, uint256 _duration) external {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_duration > 0, "Duration must be positive");
        
        marketCounter++;
        uint256 endTime = block.timestamp + _duration;
        
        markets[marketCounter] = Market({
            id: marketCounter,
            question: _question,
            endTime: endTime,
            resolved: false,
            outcome: false,
            totalYesBets: 0,
            totalNoBets: 0,
            creator: msg.sender
        });
        
        emit MarketCreated(marketCounter, _question, endTime, msg.sender);
    }
    
    /**
     * @dev Places a bet on a specific market
     * @param _marketId The ID of the market to bet on
     * @param _prediction The prediction (true for YES, false for NO)
     */
    function placeBet(uint256 _marketId, bool _prediction) external payable marketExists(_marketId) {
        Market storage market = markets[_marketId];
        require(block.timestamp < market.endTime, "Market has ended");
        require(!market.resolved, "Market already resolved");
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(bets[_marketId][msg.sender].amount == 0, "Already placed a bet on this market");
        
        bets[_marketId][msg.sender] = Bet({
            bettor: msg.sender,
            amount: msg.value,
            prediction: _prediction,
            claimed: false
        });
        
        marketBettors[_marketId].push(msg.sender);
        
        if (_prediction) {
            market.totalYesBets += msg.value;
        } else {
            market.totalNoBets += msg.value;
        }
        
        emit BetPlaced(_marketId, msg.sender, msg.value, _prediction);
    }
    
    /**
     * @dev Resolves a market with the final outcome (only owner can resolve)
     * @param _marketId The ID of the market to resolve
     * @param _outcome The final outcome (true for YES, false for NO)
     */
    function resolveMarket(uint256 _marketId, bool _outcome) external onlyOwner marketExists(_marketId) {
        Market storage market = markets[_marketId];
        require(block.timestamp >= market.endTime, "Market has not ended yet");
        require(!market.resolved, "Market already resolved");
        
        market.resolved = true;
        market.outcome = _outcome;
        
        emit MarketResolved(_marketId, _outcome);
    }
    
    /**
     * @dev Allows winners to withdraw their winnings
     * @param _marketId The ID of the market to withdraw winnings from
     */
    function withdrawWinnings(uint256 _marketId) external marketExists(_marketId) {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
        
        Bet storage userBet = bets[_marketId][msg.sender];
        require(userBet.amount > 0, "No bet found");
        require(!userBet.claimed, "Winnings already claimed");
        require(userBet.prediction == market.outcome, "Bet was incorrect");
        
        uint256 totalPool = market.totalYesBets + market.totalNoBets;
        uint256 winningPool = market.outcome ? market.totalYesBets : market.totalNoBets;
        uint256 winnings = (userBet.amount * totalPool) / winningPool;
        
        userBet.claimed = true;
        
        (bool success, ) = payable(msg.sender).call{value: winnings}("");
        require(success, "Transfer failed");
        
        emit WinningsWithdrawn(_marketId, msg.sender, winnings);
    }
    
    /**
     * @dev Get market details
     * @param _marketId The ID of the market
     */
    function getMarketDetails(uint256 _marketId) external view marketExists(_marketId) returns (
        string memory question,
        uint256 endTime,
        bool resolved,
        bool outcome,
        uint256 totalYesBets,
        uint256 totalNoBets,
        address creator
    ) {
        Market memory market = markets[_marketId];
        return (
            market.question,
            market.endTime,
            market.resolved,
            market.outcome,
            market.totalYesBets,
            market.totalNoBets,
            market.creator
        );
    }
}
