// VielFi V3 - GUI Kernel

const canvas = document.getElementById('shieldCanvas');
const ctx = canvas.getContext('2d');

let w, h, particles = [];

function initCanvas() {
    w = canvas.width = window.innerWidth;
    h = canvas.height = window.innerHeight;
}

class Particle {
    constructor() {
        this.reset();
    }
    reset() {
        this.x = Math.random() * w;
        this.y = Math.random() * h;
        this.vx = (Math.random() - 0.5) * 0.5;
        this.vy = (Math.random() - 0.5) * 0.5;
        this.size = Math.random() * 2;
    }
    update() {
        this.x += this.vx;
        this.y += this.vy;
        if (this.x < 0 || this.x > w || this.y < 0 || this.y > h) this.reset();
    }
    draw() {
        ctx.fillStyle = 'rgba(0, 242, 255, 0.5)';
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
    }
}

function animate() {
    ctx.clearRect(0, 0, w, h);
    particles.forEach(p => {
        p.update();
        p.draw();
    });
    requestAnimationFrame(animate);
}

initCanvas();
for(let i=0; i<100; i++) particles.push(new Particle());
animate();

window.addEventListener('resize', initCanvas);

// Logic
const log = document.getElementById('shieldLog');
function terminalLog(msg) {
    const time = new Date().toLocaleTimeString();
    log.innerHTML += `<div>[${time}] > ${msg}</div>`;
    log.scrollTop = log.scrollHeight;
}

document.getElementById('shieldBtn').addEventListener('click', () => {
    terminalLog('INITIATING_ZK_WITNESS_GEN...');
    setTimeout(() => terminalLog('COMMITMENT_GENERATED: 0x' + Math.random().toString(16).slice(2)), 1000);
    setTimeout(() => terminalLog('TRANSACTION_BROADCASTED_VIA_RELAYER'), 2000);
    setTimeout(() => terminalLog('VAULT_SHIELD_SUCCESS_V3'), 3000);
});

// Tab switching
const tabs = document.querySelectorAll('.tab');
tabs.forEach(tab => {
    tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        terminalLog('SWITCHING_TO_' + tab.dataset.tab.toUpperCase());
    });
});
