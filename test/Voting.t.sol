// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/Voting.sol";
import "../circuits/contract/circuits/plonk_vk.sol";

contract VotingTest is Test {
    Voting public voteContract;
    UltraVerifier public verifier;

    bytes proofBytes;
    uint256 deadline = block.timestamp + 10000000;
    
    bytes32 merkleRoot;
    bytes32 nullifierHash;


    function readInputs() internal view returns (string memory) {
        string memory inputDir = string.concat(
            vm.projectRoot(),
            "/data/input"
        );

        return vm.readFile(string.concat(inputDir, ".json"));
    }

    function setUp() public {
        string memory inputs = readInputs();
        
        merkleRoot = bytes32(vm.parseJson(inputs, ".merkleRoot"));
        nullifierHash = bytes32(vm.parseJson(inputs, ".nullifierHash"));

        verifier = new UltraVerifier();
        voteContract = new Voting(merkleRoot, address(verifier));
        voteContract.propose("First proposal", deadline);

        string memory proofFilePath = "./circuits/proofs/circuits.proof";
        string memory proof = vm.readLine(proofFilePath);
        
        proofBytes = vm.parseBytes(proof);
    }

    function test_validVote() public {
        voteContract.castVote(
            proofBytes,
            0,
            1,
            nullifierHash
        );
    }

    function test_invalidProof() public {
        vm.expectRevert(BaseUltraVerifier.EC_SCALAR_MUL_FAILURE.selector);
        voteContract.castVote(
            hex"12",
            0,
            1,
            nullifierHash
        );
    }
    
    function test_doubleVoting() public {
        voteContract.castVote(
            proofBytes,
            0,
            1,
            nullifierHash
        );

        vm.expectRevert("Proof has been already submitted");
        voteContract.castVote(
            proofBytes,
            0,
            1,
            nullifierHash
        );
    }

    function test_changedVote() public {
        vm.expectRevert(BaseUltraVerifier.PROOF_FAILURE.selector);
        
        voteContract.castVote(
            proofBytes,
            0,
            0,
            nullifierHash
        );
    }
}
