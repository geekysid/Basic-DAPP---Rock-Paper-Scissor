// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

contract RockPaperScissor {

    enum Options {Rock, Paper, Scissor}
    enum Result {Won, Loss, Tie}

    // defining player
    struct Player {
        string name;
        address walletAddress;
        uint32 winCount;
        uint32 lossCount;
        uint32 tieCount;
        uint256 balance;

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

    // EVENT Definetions
    event PlayerAdded(address indexed playerAddress, string playerName);
    event PlayerWithdrawal(address indexed playerAddress, uint256 amountWithdrawn);
    event Won(address indexed playerAddress, uint256 winningAmount);
    event Lost(address indexed playerAddress, uint256 lostAmount, Options winningOption);
    event Tie(address indexed playerAddress, uint256 winningAmount, Options winningOption);

    // MODIFIER to make sure only owners can access
    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner has accessibility to transfer funds");
        _;
    }

    // MODIFIER to make sure Player exists
    modifier playerExists() {
        require(players[msg.sender].walletAddress == msg.sender, "No such player exists");
        _;
    }

    // MODIFIER to make sure player doesnot exists
    modifier playerDoesnotExists() {
        require(players[msg.sender].walletAddress == address(0), "Player already exist with this address");
        _;
    }

    // MODIFIER to make sure player has enough balance
    modifier hasEnoughBalance(uint256 _amountWithdrawn) {
        require(players[msg.sender].balance >= _amountWithdrawn , "You don't have enough balance to withdraw");
        _;
    }

    // MODIFIER to make sure contract has enough balance
    modifier contractHasEnoughBalance {
        require(address(this).balance > 0, "Contract has nothing to withdraw/play");
        require(address(this).balance - contractDebt >= msg.value * stakes, "Contract donst has enough balance");
        _;
    }

    // HELPER FUNCTION that randomly calculates system's option
    function randomNumerHelper(Options _option) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.number, block.timestamp, _option)));
    }

    // HELPER FUNCTION that determine if player has won or lost or tied
    function gameRule(Options _playerOption, Options _randomOption) internal pure returns (Result outcome) {
        if (_playerOption == _randomOption) {
            outcome = Result.Tie;
        } else {
            if (_playerOption == Options.Rock) {
                if (_randomOption == Options.Scissor){
                    outcome = Result.Won;
                } else {
                    outcome = Result.Loss;
                }

            } else if (_playerOption == Options.Scissor) {
                if (_randomOption == Options.Paper){
                    outcome = Result.Won;
                } else {
                    outcome = Result.Loss;
                }
            } else  if (_playerOption == Options.Paper) {
                if (_randomOption == Options.Rock){
                    outcome = Result.Won;
                } else {
                    outcome = Result.Loss;
                }
            }
        }
    }

    // FUNCTION to allow player to start game
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
            emit Won(msg.sender, _winningAmount);
        } else if (_outcome == Result.Tie) {
            uint256 _winningAmount = msg.value;
            contractDebt += _winningAmount;
            players[msg.sender].balance += _winningAmount;
            players[msg.sender].tieCount += 1;
            emit Tie(msg.sender, _winningAmount, _winningOption);
        } else if (_outcome == Result.Loss) {
            players[msg.sender].lossCount += 1;
            emit Lost(msg.sender, msg.value, _winningOption);
        }
    }

    // FUNCTION to allow player to register itself
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

    // FUNCTION to allow player to get its details
    function getPlayer() external playerExists view returns (Player memory) {
        return players[msg.sender];
    }

    // FUNCTION to allow player to get its balance
    function getPlayerBalance() external playerExists view returns (uint256) {
        return players[msg.sender].balance;
    }

    // FUNCTION to allow player to withdraw its balance
    function playerWithdrawal(uint256 _amountWithdrawn) external payable playerExists hasEnoughBalance(_amountWithdrawn) {
        players[msg.sender].balance -= _amountWithdrawn;
        contractDebt -= _amountWithdrawn;
        payable(msg.sender).transfer(_amountWithdrawn);
        emit PlayerWithdrawal(msg.sender, _amountWithdrawn);
    }

    // FUNCTION to allow owner to know that is the maximum that he can withdraw from contract
    function ownerGetMaxWithdrawalAvailable() public view returns(uint256) {
        require(address(this).balance > contractDebt, "Contract has more debt as compare to balance. So you cant withdraw anything");
        uint256 _maxWithdrawalAvailable = ((address(this).balance - contractDebt) * maxWithdrawPercentOwner) / 100;
        return _maxWithdrawalAvailable;
    }

    // FUNCTION to allow owner to withdraw from contract
    function ownerWithdrawal(uint256 _amount) payable external onlyOwner {
        require(ownerGetMaxWithdrawalAvailable() >= _amount, "Not enough balance to withdraw");
        payable(owner).transfer(_amount);
    }

    // FUNCTION to allow owner to add funds to contract
    function ownerAddFunds() payable external onlyOwner {
    }

    // FUNCTION to allow owner to know total contcat's balance
    function getContractBalance()external onlyOwner view returns (uint256) {
        return address(this).balance;
    }

    // FUNCTION to allow owner to know how much contract owes to player
    function getContractDebt()external onlyOwner view returns (uint256) {
        return contractDebt;
    }
}