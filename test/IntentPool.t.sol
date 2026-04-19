// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IntentPool} from "src/sequencer/IntentPool.sol";

contract IntentPoolTest is Test {
    IntentPool pool;

    uint256 userPk = 0xA11CE;
    address user;
    address solver = address(0xBEEF);
    address otherSolver = address(0xCAFE);

    bytes32 internal constant WITHDRAWAL_INTENT_TYPEHASH =
        keccak256(
            "WithdrawalIntent(address user,bytes32 nullifierHash,bytes32 root,address recipient,uint256 denomination,address relayer,uint256 fee,bytes32 proofHash,uint256 nonce,uint64 deadline)"
        );

    function setUp() public {
        pool = new IntentPool();
        user = vm.addr(userPk);
    }

    function _intent(address relayer, uint256 nonce, uint64 deadline)
        internal
        view
        returns (IntentPool.WithdrawalIntent memory i)
    {
        i = IntentPool.WithdrawalIntent({
            user: user,
            nullifierHash: keccak256("nullifier"),
            root: bytes32(uint256(123)),
            recipient: address(0x1234),
            denomination: 100_000_000,
            relayer: relayer,
            fee: 1_000,
            proofHash: keccak256("proof"),
            nonce: nonce,
            deadline: deadline
        });
    }

    function _sign(IntentPool.WithdrawalIntent memory i) internal view returns (bytes memory sig) {
        bytes32 structHash = keccak256(
            abi.encode(
                WITHDRAWAL_INTENT_TYPEHASH,
                i.user,
                i.nullifierHash,
                i.root,
                i.recipient,
                i.denomination,
                i.relayer,
                i.fee,
                i.proofHash,
                i.nonce,
                i.deadline
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NOFACE IntentPool")),
                keccak256(bytes("1")),
                block.chainid,
                address(pool)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function test_submitIntentStoresRecordAndIncrementsNonce() public {
        IntentPool.WithdrawalIntent memory i = _intent(address(0), 0, uint64(block.timestamp + 1 hours));
        bytes memory sig = _sign(i);

        bytes32 id = pool.submitWithdrawalIntent(i, sig);
        (address recUser, address relayer,, uint64 deadline, IntentPool.IntentStatus status) = pool.intents(id);

        assertEq(recUser, user);
        assertEq(relayer, address(0));
        assertEq(deadline, i.deadline);
        assertEq(uint256(status), uint256(IntentPool.IntentStatus.Open));
        assertEq(pool.nonces(user), 1);
    }

    function test_claimPermissionlessIntent() public {
        IntentPool.WithdrawalIntent memory i = _intent(address(0), 0, uint64(block.timestamp + 1 hours));
        bytes32 id = pool.submitWithdrawalIntent(i, _sign(i));

        vm.prank(solver);
        pool.claimIntent(id);

        (,, address claimer,, IntentPool.IntentStatus status) = pool.intents(id);
        assertEq(claimer, solver);
        assertEq(uint256(status), uint256(IntentPool.IntentStatus.Claimed));
    }

    function test_claimRestrictedIntentRejectsWrongSolver() public {
        IntentPool.WithdrawalIntent memory i = _intent(solver, 0, uint64(block.timestamp + 1 hours));
        bytes32 id = pool.submitWithdrawalIntent(i, _sign(i));

        vm.prank(otherSolver);
        vm.expectRevert(IntentPool.UnauthorizedSolver.selector);
        pool.claimIntent(id);
    }

    function test_cancelOpenIntentByOwner() public {
        IntentPool.WithdrawalIntent memory i = _intent(address(0), 0, uint64(block.timestamp + 1 hours));
        bytes32 id = pool.submitWithdrawalIntent(i, _sign(i));

        vm.prank(user);
        pool.cancelIntent(id);

        (,,,, IntentPool.IntentStatus status) = pool.intents(id);
        assertEq(uint256(status), uint256(IntentPool.IntentStatus.Cancelled));
    }
}

