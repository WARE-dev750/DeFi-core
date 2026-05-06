// VielFi | Privacy Kernel UI Logic

// Tab Switching
const tabs = document.querySelectorAll('.tab-btn');
const actionBtn = document.getElementById('actionBtn');
const amountInput = document.getElementById('amountInput');

let currentTab = 'shield';

tabs.forEach(tab => {
    tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        currentTab = tab.dataset.tab;
        
        // Update UI based on tab
        if (currentTab === 'shield') {
            actionBtn.innerText = 'Generate Proof';
        } else if (currentTab === 'unshield') {
            actionBtn.innerText = 'Verify & Withdraw';
        } else {
            actionBtn.innerText = 'Execute Swap';
        }
    });
});

// Action Handling
actionBtn.addEventListener('click', async () => {
    actionBtn.disabled = true;
    const originalText = actionBtn.innerText;
    actionBtn.innerText = 'Processing...';

    try {
        // Simulate SDK Interaction
        console.log(`[VielFi] Initiating ${currentTab} for ${amountInput.value} USDC...`);
        
        await new Promise(resolve => setTimeout(resolve, 1500));
        
        updatePrivacySet();
        alert(`${currentTab.toUpperCase()} operation successful.`);
    } catch (error) {
        console.error('Operation failed', error);
        alert('Operation failed. Please check console.');
    } finally {
        actionBtn.disabled = false;
        actionBtn.innerText = originalText;
    }
});

// Privacy Set Simulation
function updatePrivacySet() {
    const set = Math.floor(Math.random() * 1000) + 500;
    document.getElementById('privacySet').innerText = `${set} Notes`;
}

// Initial Load
updatePrivacySet();

// Wallet Connection Mock
document.getElementById('connectBtn').addEventListener('click', () => {
    const btn = document.getElementById('connectBtn');
    if (btn.innerText === 'Connect Wallet') {
        btn.innerText = '0x71...C42';
        btn.style.opacity = '0.5';
    } else {
        btn.innerText = 'Connect Wallet';
        btn.style.opacity = '1';
    }
});

