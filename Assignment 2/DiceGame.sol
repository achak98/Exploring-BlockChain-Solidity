// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

contract DiceGame {
    struct Game {
        address address1;
        bytes32 p1commit;
        string p1secret;
        address address2;
        bytes32 p2commit;
        string p2secret;
        bool p1Ready;
        bool p2Ready;
        State state;
        uint256 lastCommitBlockNumberWithOffset;
    }

    enum State {
        INACTIVE,
        IN_LOBBY,
        LIVE
    }

    Game private game;
    mapping(address => uint256) balance;
    address[] private players;
    bytes32[] private commitedHashes;
    mapping(bytes32 => bool) commitedHashesMap;

    event Deposit(address customer, uint256 amount);
    event Withdrawal(address customer);
    event DeclareResult(address customer, string message);

    uint256 BLOCK_OFFSET = 2;
    uint256 PLAY_FEE = 50000;
    uint256 BUY_IN_FEE = 1.5e18;

    function checkIntegerOverflowAndUnderflow(
        uint256 a,
        uint256 b,
        uint256 c,
        uint256 d
    ) private pure {
        require(a + b > c); //checks integer underflow for playing, and overflow for depositing balance
        require(b + a + d - c > 0); // checks integer overflow for winning
    }

    function withdraw() public {
        uint256 b = balance[msg.sender];
        balance[msg.sender] = 0;
        payable(msg.sender).transfer(b);
        emit Withdrawal(msg.sender);
    }

    function getBalance() public view returns (uint256) {
        return balance[msg.sender];
    }

    function willSatisfyBlockOffset() public view returns (bool) {
        return game.lastCommitBlockNumberWithOffset < block.number;
    }

    function rollDice() private view returns (uint256) {
        bytes32 p1Rand = keccak256(abi.encodePacked(game.p1secret));
        bytes32 p2Rand = keccak256(abi.encodePacked(game.p2secret));
        bytes32 contractRand = keccak256(
            abi.encodePacked(blockhash(block.number))
        );
        return
            (uint256(
                keccak256(abi.encodePacked(contractRand ^ p1Rand ^ p2Rand))
            ) % 6) + 1;
    }

    function playerReady(string memory message) public {
        require(game.state == State.LIVE);
        if (!game.p1Ready && !game.p2Ready) {
            if (msg.sender == game.address1) {
                if (keccak256(abi.encodePacked(message)) == game.p1commit) {
                    game.p1Ready = true;
                    game.p1secret = message;
                }
            } else if (msg.sender == game.address2) {
                if (keccak256(abi.encodePacked(message)) == game.p2commit) {
                    game.p2Ready = true;
                    game.p2secret = message;
                }
            }
            game.lastCommitBlockNumberWithOffset = block.number + BLOCK_OFFSET;
        } else if (willSatisfyBlockOffset()) {
            if (game.p1Ready && !game.p2Ready) {
                if (msg.sender == game.address2) {
                    if (keccak256(abi.encodePacked(message)) == game.p2commit) {
                        game.p2Ready = true;
                        game.p2secret = message;
                    }
                }
            } else if (!game.p1Ready && game.p2Ready) {
                if (msg.sender == game.address1) {
                    if (keccak256(abi.encodePacked(message)) == game.p1commit) {
                        game.p1Ready = true;
                        game.p1secret = message;
                    }
                }
            }
            game.lastCommitBlockNumberWithOffset = block.number + BLOCK_OFFSET;
        } else {
            revert();
        }
    }

    function play() public {
        require(willSatisfyBlockOffset() && game.p1Ready && game.p2Ready);
        uint256 result = rollDice();
        if (result < 4) {
            balance[game.address1] += (result) * 1e18;
            emit DeclareResult(game.address1, "Won!");
        } else {
            balance[game.address2] += (result - 3) * 1e18;
            emit DeclareResult(game.address2, "Won!");
        }
        game.state = State.INACTIVE;
        balance[msg.sender] += PLAY_FEE;
    }

    function freeGame() public {
        require(game.state == State.LIVE);
        balance[game.address1] += 1e18 + PLAY_FEE / 2;
        balance[game.address2] += 1e18 + PLAY_FEE / 2;
        game.state = State.INACTIVE;
    }

    function getGameState() public view returns (State) {
        return game.state;
    }

    function joinGame(bytes32 commit) public payable {
        require(game.state == State.IN_LOBBY || game.state == State.INACTIVE);
        require(!commitedHashesMap[commit]); //checks that commit values aren't used twice (otherwise attacker can know what the hash's preimage is
        checkIntegerOverflowAndUnderflow(
            balance[msg.sender],
            msg.value,
            BUY_IN_FEE + PLAY_FEE / 2,
            3e18
        ); //1.5 eth entry fee + gas for calling play() function, also checks for overflow condition in event of winning 3 eth
        balance[msg.sender] =
            balance[msg.sender] +
            msg.value -
            (BUY_IN_FEE + (PLAY_FEE / 2)); //1.5 ETH entry fee + some more to be returned to user calling play()
        players.push(msg.sender);
        emit Deposit(
            msg.sender,
            msg.value - (BUY_IN_FEE + (PLAY_FEE / 2))
        );
        if (game.state == State.IN_LOBBY && game.address1 != msg.sender) {
            game.address2 = msg.sender;
            game.p2commit = commit;
            game.state = State.LIVE;
            commitedHashes.push(commit);
            commitedHashesMap[commit] = true;
        } else if (game.state == State.INACTIVE) {
            game.address1 = msg.sender;
            game.p1commit = commit;
            game.state = State.IN_LOBBY;
            commitedHashes.push(commit);
            commitedHashesMap[commit] = true;
        } else {
            revert();
        }
    }

    function init() public payable {
        players.push(msg.sender);
    }

    function empty() public {
        require(msg.sender == players[0]);
        selfdestruct(payable(msg.sender));
    }
}
