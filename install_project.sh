#!/bin/bash

# اطمینان از اینکه سیستم به روز است
sudo apt update -y && sudo apt upgrade -y

# نصب پیش نیازها
sudo apt install -y nodejs npm curl python3 python3-pip git

# نصب Truffle و TronBox
npm install -g truffle
npm install -g tronbox

# نصب کتابخانه‌های مورد نیاز
npm install tronweb axios dotenv readline-sync

# نصب پکیج‌های Python برای استفاده از API (در صورت نیاز)
pip3 install requests

# ساخت پروژه Truffle
mkdir myTokenProject
cd myTokenProject
tronbox init

# ساخت فایل .env برای ذخیره اطلاعات حساس
echo "TRON_API_KEY=your_tron_api_key" >> .env
echo "COINMARKETCAP_API_KEY=your_coinmarketcap_api_key" >> .env
echo "SHASTA_FAUCET_URL=https://faucet.shasta.tron.network" >> .env

# ایجاد کیف پول جدید با TronWeb
cat > create_wallet.js <<EOF
const TronWeb = require('tronweb');
const HttpProvider = TronWeb.providers.HttpProvider;
const readlineSync = require('readline-sync');

// تنظیمات شبکه (تست یا اصلی)
const tronAPI = 'https://api.trongrid.io'; // برای شبکه اصلی، برای تست می‌توانید از http://api.shasta.trongrid.io استفاده کنید
const tronWeb = new TronWeb({
    fullHost: tronAPI,
});

async function createWallet() {
    try {
        const wallet = await tronWeb.createAccount();
        console.log('آدرس عمومی:', wallet.address.base58);
        console.log('کلید خصوصی:', wallet.privateKey);

        if (tronAPI === 'https://api.shasta.trongrid.io') {
            // در صورت استفاده از شبکه تست، دریافت توکن تستی از Faucet
            const faucetUrl = process.env.SHASTA_FAUCET_URL;
            console.log('در حال ارسال درخواست برای دریافت توکن‌های تستی از Faucet...');
            await requestFaucet(wallet.address.base58, faucetUrl);
        } else {
            console.log('برای دریافت توکن‌های اصلی، آدرس را به دیگران ارسال کنید.');
        }
    } catch (error) {
        console.error("خطا در ایجاد کیف پول:", error);
    }
}

async function requestFaucet(address, faucetUrl) {
    try {
        const response = await axios.post(faucetUrl, {
            address: address,
        });

        if (response.data.status === 'ok') {
            console.log('توکن‌های تستی به آدرس شما ارسال شدند.');
            await waitForDeposit(address);
        } else {
            console.error('خطا در ارسال توکن‌های تستی.');
        }
    } catch (error) {
        console.error('خطا در ارتباط با Faucet:', error);
    }
}

async function waitForDeposit(address) {
    console.log('لطفاً برای چند ثانیه صبر کنید تا واریز تایید شود.');
    let depositConfirmed = false;

    // بررسی موجودی به طور دوره‌ای
    while (!depositConfirmed) {
        const balance = await tronWeb.trx.getBalance(address);
        if (balance > 0) {
            console.log(`واریز تایید شد! موجودی شما: ${balance} TRX`);
            depositConfirmed = true;
        } else {
            console.log('هنوز واریزی تایید نشده است. مجدداً بررسی می‌کنیم...');
            await new Promise(resolve => setTimeout(resolve, 3000));  // 3 ثانیه صبر می‌کنیم
        }
    }
}

createWallet();
EOF

# اجرای اسکریپت ایجاد کیف پول
echo "لطفاً نوع شبکه را وارد کنید (1 برای شبکه تست، 2 برای شبکه اصلی):"
read network_choice
node create_wallet.js $network_choice

# دریافت قیمت USDT از CoinMarketCap یا CoinGecko
cat > fetch_price.js <<EOF
const axios = require('axios');
require('dotenv').config();

const coinMarketCapApiKey = process.env.COINMARKETCAP_API_KEY;

async function fetchUSDTPrice() {
    try {
        const response = await axios.get('https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest', {
            headers: {
                'X-CMC_PRO_API_KEY': coinMarketCapApiKey,
                'Accept': 'application/json',
            },
            params: {
                'symbol': 'USDT',
            },
        });
        const usdtPrice = response.data.data[0].quote.USD.price;
        console.log('قیمت USDT:', usdtPrice);
    } catch (error) {
        console.error('خطا در دریافت قیمت:', error);
    }
}

fetchUSDTPrice();
EOF

# اجرای اسکریپت دریافت قیمت
node fetch_price.js

# ایجاد قرارداد هوشمند برای توکن جعلی (ERC-20 مشابه با TRC-20 برای Tron)
cat > TokenContract.sol <<EOF
pragma solidity ^0.5.8;

contract FakeUSDT {
    string public name = "Fake USDT";
    string public symbol = "FUSDT";
    uint8 public decimals = 18;
    uint256 public totalSupply = 100000000 * (10 ** uint256(decimals));
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        require(to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(from != address(0), "Invalid address");
        require(to != address(0), "Invalid address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
}
EOF

# کامپایل قرارداد
tronbox compile

# انتشار قرارداد به شبکه ترون
cat > deploy_contract.js <<EOF
const TronWeb = require('tronweb');
const HttpProvider = TronWeb.providers.HttpProvider;

const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    privateKey: 'your_private_key', // کلید خصوصی که از ایجاد کیف پول به دست آوردید
});

async function deployContract() {
    const contract = await tronWeb.contract().new({
        abi: require('./build/contracts/FakeUSDT.json').abi,
        bytecode: require('./build/contracts/FakeUSDT.json').evm.bytecode.object,
    });

    const result = await contract.deploy();
    console.log('آدرس قرارداد جدید:', result.address);
}

deployContract();
EOF

# اجرای اسکریپت نشر قرارداد
node deploy_contract.js

echo "پروژه با موفقیت ساخته شد و توکن جعلی ایجاد شد."