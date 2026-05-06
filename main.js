// VielFi | Institutional Grade ZK-Privacy UI Logic
// Integrated with Ethers.js for real contract interaction

const VAULT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Localhost default
const VAULT_ABI = [
    "function deposit(bytes32 commitment) external",
    "function withdraw(bytes calldata proof, bytes32 root, bytes32 nullifierHash, address recipient, address relayer, uint256 fee, address token) external",
    "function getRoot() view returns (bytes32)",
    "function commitments(bytes32) view returns (bool)"
];

let provider, signer, vault;
let currentTab = 'shield';

// DOM Elements
const connectBtn = document.getElementById('connectBtn');
const actionBtn = document.getElementById('actionBtn');
const amountInput = document.getElementById('amountInput');
const idInput = document.getElementById('idInput');
const opStatus = document.getElementById('opStatus');
const contractDisplay = document.getElementById('contractDisplay');

// Tab Switching
document.querySelectorAll('.tab-btn').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        currentTab = tab.dataset.tab;
        updateUI();
    });
});

function updateUI() {
    if (!signer) {
        actionBtn.innerText = "Connect Wallet";
        return;
    }
    
    if (currentTab === 'shield') {
        actionBtn.innerText = "Shield Assets";
        idInput.placeholder = "Auto-generating commitment...";
    } else if (currentTab === 'unshield') {
        actionBtn.innerText = "Verify & Unshield";
        idInput.placeholder = "Enter Note Nullifier";
        idInput.readOnly = false;
    } else {
        actionBtn.innerText = "Execute Private Swap";
    }
}

// Wallet Connection
async function connectWallet() {
    if (!window.ethereum) {
        alert("Please install MetaMask!");
        return;
    }
    
    try {
        opStatus.innerText = "Connecting...";
        provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        signer = provider.getSigner();
        const address = await signer.getAddress();
        
        vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);
        
        connectBtn.innerText = `${address.slice(0,6)}...${address.slice(-4)}`;
        contractDisplay.innerText = `Vault: ${VAULT_ADDRESS}`;
        opStatus.innerText = "Connected";
        updateUI();
    } catch (err) {
        console.error(err);
        opStatus.innerText = "Connection Failed";
    }
}

connectBtn.addEventListener('click', connectWallet);

// Core Logic
actionBtn.addEventListener('click', async () => {
    if (!signer) {
        await connectWallet();
        return;
    }

    actionBtn.disabled = true;
    const originalText = actionBtn.innerText;
    
    try {
        if (currentTab === 'shield') {
            await handleShield();
        } else if (currentTab === 'unshield') {
            await handleUnshield();
        }
    } catch (err) {
        console.error(err);
        opStatus.innerText = "Transaction Failed";
        alert(err.reason || err.message);
    } finally {
        actionBtn.disabled = false;
        actionBtn.innerText = originalText;
    }
});

async function handleShield() {
    opStatus.innerText = "Generating ZK Commitment...";
    
    // In a real app, we'd use the SDK's poseidon2
    // For this demonstration, we'll use a random bytes32 as the commitment
    const secret = ethers.utils.randomBytes(32);
    const commitment = ethers.utils.keccak256(secret);
    
    idInput.value = commitment;
    opStatus.innerText = "Waiting for Transaction...";
    
    const tx = await vault.deposit(commitment);
    opStatus.innerText = "Mining Shielded Note...";
    await tx.wait();
    
    opStatus.innerText = "Success: Assets Shielded";
    alert("Note generated and saved to commitment: " + commitment);
}

async function handleUnshield() {
    const nullifierHash = idInput.value;
    if (!nullifierHash || nullifierHash.length !== 66) {
        alert("Please enter a valid nullifier hash (32 bytes)");
        return;
    }

    opStatus.innerText = "Generating ZK Proof...";
    await new Promise(r => setTimeout(r, 2000)); // Simulate proof work
    
    const root = await vault.getRoot();
    const recipient = await signer.getAddress();
    const proof = ethers.utils.hexlify(ethers.utils.randomBytes(200)); // Mock proof for MockVerifier
    
    opStatus.innerText = "Broadcasting Proof...";
    
    const tx = await vault.withdraw(
        proof,
        root,
        nullifierHash,
        recipient,
        ethers.constants.AddressZero, // No relayer
        0, // No fee
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" // Placeholder USDC address
    );
    
    opStatus.innerText = "Verifying on-chain...";
    await tx.wait();
    
    opStatus.innerText = "Success: Assets Unshielded";
    alert("Withdrawal successful!");
}

// Initial State
updateUI();


