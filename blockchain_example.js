const crypto = require('crypto');

class Transaction {
  constructor(sender, recipient, amount, memo = '') {
    this.sender = sender;
    this.recipient = recipient;
    this.amount = amount;
    this.memo = memo;
  }
}

class Block {
  constructor(index, timestamp, transactions, previousHash = '') {
    this.index = index;
    this.timestamp = timestamp;
    this.transactions = transactions;
    this.previousHash = previousHash;
    this.nonce = 0;
    this.hash = this.calculateHash();
  }

  calculateHash() {
    const data = this.index + this.timestamp + JSON.stringify(this.transactions) + this.previousHash + this.nonce;
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  mineBlock(difficulty) {
    while (this.hash.substring(0, difficulty) !== Array(difficulty + 1).join('0')) {
      this.nonce++;
      this.hash = this.calculateHash();
    }
    console.log('Block mined:', this.hash);
  }
}

class Blockchain {
  constructor() {
    this.chain = [this.createGenesisBlock()];
    this.difficulty = 4;
    this.pendingTransactions = [];
  }

  createGenesisBlock() {
    return new Block(0, Date.now(), 'Genesis Block', '0');
  }

  getLatestBlock() {
    return this.chain[this.chain.length - 1];
  }

  addTransaction(transaction) {
    this.pendingTransactions.push(transaction);
  }

  minePendingTransactions(minerAddress) {
    const block = new Block(this.chain.length, Date.now(), this.pendingTransactions, this.getLatestBlock().hash);
    block.mineBlock(this.difficulty);
    this.chain.push(block);
    this.pendingTransactions = [new Transaction(null, minerAddress, 1, 'Mining reward')];
  }

  isChainValid() {
    for (let i = 1; i < this.chain.length; i++) {
      const current = this.chain[i];
      const previous = this.chain[i - 1];
      if (current.hash !== current.calculateHash()) return false;
      if (current.previousHash !== previous.hash) return false;
    }
    return true;
  }
}

function processCardPayment(cardNumber, amount) {
  console.log(`Visa/Mastercard payment: ${amount} USD from ${cardNumber}`);
  return true;
}

function payoutSalary(account, amount) {
  console.log(`Salary payout ${amount} USD to ${account}`);
  return true;
}

function payoutBusiness(account, amount) {
  console.log(`Business payout ${amount} USD to ${account}`);
  return true;
}

const coin = new Blockchain();
coin.addTransaction(new Transaction('miner1', 'worker1', 100, 'Salary'));
coin.minePendingTransactions('miner1');
processCardPayment('4111111111111111', 150);
payoutSalary('worker1_wallet', 800);
payoutBusiness('company_wallet', 2000);
console.log('Chain valid:', coin.isChainValid());
