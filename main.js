// VielFi SDK Initialization & GUI Logic

document.addEventListener('DOMContentLoaded', () => {
    console.log('VielFi GUI Initialized');
    
    const connectBtn = document.getElementById('connectWallet');
    
    connectBtn.addEventListener('click', async () => {
        if (typeof window.ethereum !== 'undefined') {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
                const account = accounts[0];
                connectBtn.innerText = account.substring(0, 6) + '...' + account.substring(38);
                connectBtn.style.background = 'var(--accent-glow)';
                console.log('Connected:', account);
            } catch (error) {
                console.error('User rejected connection');
            }
        } else {
            alert('Please install MetaMask to use VielFi!');
        }
    });

    // Simple interaction animation
    const cards = document.querySelectorAll('.feature-card');
    cards.forEach(card => {
        card.addEventListener('mouseenter', () => {
            card.style.borderColor = 'var(--accent-color)';
        });
        card.addEventListener('mouseleave', () => {
            card.style.borderColor = 'var(--glass-border)';
        });
    });
});
