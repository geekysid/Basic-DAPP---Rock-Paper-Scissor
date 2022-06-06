// SPDX-License-Identifier: ISC
pragma solidity ^0.8.5;

contract RockPaperScissor {

    enum Options {Rock, Paper, Scissor}     // available options that player can choose from
    enum Result {Won, Loss, Tie}            // all possible outcome of a game

    // Player object
    struct Player {
        string name;                // name of player
        address walletAddress;      // eth wallet address of player
        uint32 winCount;            // number of games player has won
        uint32 lossCount;           // number of games player has lost
        uint32 tieCount;            // number of games player has tied
        uint256 balance;            // total balance of players

    }
    mapping(address => Player) players;     // mapping of payer's address to its data
    address owner;                          // address of owner
    uint8 stakes;                           // value of stakes to which betting amount will be multiplied
    uint8 maxWithdrawPercentOwner = 10;     // percentage of maximum ether, owner can withdraw from contract
    uint256 contractDebt;                   // total numbe rof ethers that contract owes to players

    constructor(uint8 _stakes) {
        owner = msg.sender;
        stakes = _stakes;
    }

    // EVENT Definitions
    event PlayerAdded(address indexed playerAddress, string playerName);                    // to be emited when new player registers himself
    event PlayerWithdrawal(address indexed playerAddress, uint256 amountWithdrawn);         // to be emited when players withdraws his winnings
    event GameResult(address indexed playerAddress, Result result, uint256 winningAmount, Options winningOption);  // to be emited to depict outcome of a game

    /* @title MODIFIER to make sure only owners can access */
    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner has accessibility to transfer funds");
        _;
    }

    /* @title MODIFIER to make sure Player exists */
    modifier playerExists() {
        require(players[msg.sender].walletAddress == msg.sender, "No such player exists");
        _;
    }

    /* @title MODIFIER tto make sure player doesnot exists */
    modifier playerDoesnotExists() {
        require(players[msg.sender].walletAddress == address(0), "Player already exist with this address");
        _;
    }

    /* @title MODIFIER tto make sure player has enough balance */
    modifier hasEnoughBalance(uint256 _amountWithdrawn) {
        require(players[msg.sender].balance >= _amountWithdrawn , "You don't have enough balance to withdraw");
        _;
    }

    /* @title MODIFIER tto make sure contract has enough balance */
    modifier contractHasEnoughBalance {
        require(address(this).balance > 0, "Contract has nothing to withdraw/play");
        require(address(this).balance - contractDebt >= msg.value * stakes, "Contract donst has enough balance");
        _;
    }

    /**
        * @dev UTILITY FUNCTION that randomly calculates system's option
        * @param _option Options that player has selected
        * @return uint256 randome number.
    */
    function randomNumerHelper(Options _option) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.number, block.timestamp, _option)));
    }

    /**
        * @dev FUNCTION that determine if player has won or lost or tied
        * @param _playerOption Options that player has selected
        * @param _randomOption Options was selected randomly
        * @return _outcome Result of game.
    */
    function gameRule(Options _playerOption, Options _randomOption) internal pure returns (Result _outcome) {
        if (_playerOption == _randomOption) {
            _outcome = Result.Tie;
        } else {
            if (_playerOption == Options.Rock) {
                if (_randomOption == Options.Scissor){
                    _outcome = Result.Won;
                } else {
                    _outcome = Result.Loss;
                }

            } else if (_playerOption == Options.Scissor) {
                if (_randomOption == Options.Paper){
                    _outcome = Result.Won;
                } else {
                    _outcome = Result.Loss;
                }
            } else  if (_playerOption == Options.Paper) {
                if (_randomOption == Options.Rock){
                    _outcome = Result.Won;
                } else {
                    _outcome = Result.Loss;
                }
            }
        }
    }

    /**
        * @dev FUNCTION that allows player to register itself
        * @param _playerName String Name if a player
    */
    function registerPlayer(string memory _playerName) external playerDoesnotExists {
        players[msg.sender] = Player({
            name: _playerName,
            walletAddress: msg.sender,
            winCount: 0,
            lossCount: 0,
            tieCount: 0,
            balance: 0
        });
        emit PlayerAdded(msg.sender, _playerName);
    }

    /**
        * @dev PAYBALE FUNCTION that allow player to start game
        * @param _playerOption Options that player has selected
    */
    function startPlay(Options _playerOption) payable external playerExists contractHasEnoughBalance {
        require(msg.value == 1 ether, "You can only bet 1 Ether");
        uint256 _randomNumber = randomNumerHelper(_playerOption);
        Options _winningOption = Options(_randomNumber%3);
        Result _outcome = gameRule(_playerOption, _winningOption);
        if (_outcome == Result.Won) {
            uint256 _winningAmount = msg.value * stakes;
            contractDebt += _winningAmount;
            players[msg.sender].balance += _winningAmount;
            players[msg.sender].winCount += 1;
            // emit Won(msg.sender, _winningAmount);
        } else if (_outcome == Result.Tie) {
            uint256 _winningAmount = msg.value;
            contractDebt += _winningAmount;
            players[msg.sender].balance += _winningAmount;
            players[msg.sender].tieCount += 1;
            // emit Tie(msg.sender, _winningAmount, _winningOption);
        } else if (_outcome == Result.Loss) {
            players[msg.sender].lossCount += 1;
            // emit Lost(msg.sender, msg.value, _winningOption);
        }
        emit GameResult(msg.sender, _outcome, msg.value, _winningOption);
    }

    /**
        * @dev paybale FUNCTION to allow owner to add funds to contract
    */
    function ownerAddFunds() payable external onlyOwner {
    }

    /**
        * @dev Payable FUNCTION that allows player to register itself
        * @param _amountWithdrawn uint256 amount that player needs to withdraw
    */
    function playerWithdrawal(uint256 _amountWithdrawn) external payable playerExists hasEnoughBalance(_amountWithdrawn) {
        players[msg.sender].balance -= _amountWithdrawn;
        contractDebt -= _amountWithdrawn;
        payable(msg.sender).transfer(_amountWithdrawn);
        emit PlayerWithdrawal(msg.sender, _amountWithdrawn);
    }

    /**
        * @dev Payable FUNCTION that allow owner to withdraw from contract
        * @param _amount uint256 amount that player needs to withdraw
    */
    function ownerWithdrawal(uint256 _amount) payable external onlyOwner {
        require(ownerGetMaxWithdrawalAvailable() >= _amount, "Not enough balance to withdraw");
        payable(owner).transfer(_amount);
    }

    /**
        * @dev Getter FUNCTION to allow player to get his details
        * @return Player details.
    */
    function getPlayer() external playerExists view returns (Player memory) {
        return players[msg.sender];
    }

    /**
        * @dev Getter FUNCTION to allow player to get its balance
        * @return uint256
    */
    function getPlayerBalance() external playerExists view returns (uint256) {
        return players[msg.sender].balance;
    }

    /**
        * @dev Getter FUNCTION to allow owner to know that is the maximum that he can withdraw from contract
        * @return uint256
    */
    function ownerGetMaxWithdrawalAvailable() public view returns(uint256) {
        require(address(this).balance > contractDebt, "Contract has more debt as compare to balance. So you cant withdraw anything");
        uint256 _maxWithdrawalAvailable = ((address(this).balance - contractDebt) * maxWithdrawPercentOwner) / 100;
        return _maxWithdrawalAvailable;
    }

    /**
        * @dev Getter FUNCTION to allow owner to know total contcat's balance
        * @return uint256
    */
    function getContractBalance()external onlyOwner view returns (uint256) {
        return address(this).balance;
    }

    /**
        * @dev Getter FUNCTION to allow owner to know how much contract owes to player
        * @return uint256
    */
    function getContractDebt()external onlyOwner view returns (uint256) {
        return contractDebt;
    }
}