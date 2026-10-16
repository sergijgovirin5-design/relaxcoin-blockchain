use sha2::{Digest, Sha256};
use serde::{Serialize, Deserialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Transaction {
    sender: String,
    recipient: String,
    amount: f64,
    memo: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Block {
    index: u64,
    timestamp: u128,
    transactions: Vec<Transaction>,
    previous_hash: String,
    nonce: u64,
    hash: String,
}

impl Block {
    fn calculate_hash(&self) -> String {
        let block_string = serde_json::to_string(&(
            self.index,
            self.timestamp,
            &self.transactions,
            &self.previous_hash,
            self.nonce,
        )).unwrap();

        let mut hasher = Sha256::new();
        hasher.update(block_string);
        format!("{:x}", hasher.finalize())
    }
}

struct Blockchain {
    chain: Vec<Block>,
    pending_transactions: Vec<Transaction>,
    difficulty: usize,
}

impl Blockchain {
    fn new() -> Self {
        let mut blockchain = Blockchain {
            chain: vec![],
            pending_transactions: vec![],
            difficulty: 4,
        };
        blockchain.create_genesis_block();
        blockchain
    }

    fn create_genesis_block(&mut self) {
        let genesis = Block {
            index: 0,
            timestamp: current_timestamp(),
            transactions: vec![],
            previous_hash: String::from("0"),
            nonce: 0,
            hash: String::new(),
        };
        let mut genesis = genesis;
        genesis.hash = genesis.calculate_hash();
        self.chain.push(genesis);
    }

    fn get_latest_block(&self) -> &Block {
        self.chain.last().unwrap()
    }

    fn add_transaction(&mut self, transaction: Transaction) {
        self.pending_transactions.push(transaction);
    }

    fn mine_pending_transactions(&mut self, miner_address: String) {
        let mut block = Block {
            index: self.chain.len() as u64,
            timestamp: current_timestamp(),
            transactions: self.pending_transactions.clone(),
            previous_hash: self.get_latest_block().hash.clone(),
            nonce: 0,
            hash: String::new(),
        };

        self.proof_of_work(&mut block);
        self.chain.push(block);
        self.pending_transactions = vec![Transaction { sender: String::from("SYSTEM"), recipient: miner_address, amount: 1.0, memo: String::from("block reward") }];
    }

    fn proof_of_work(&self, block: &mut Block) {
        let target = "0".repeat(self.difficulty);
        while !block.hash.starts_with(&target) {
            block.hash = block.calculate_hash();
            block.nonce += 1;
        }
    }

    fn is_chain_valid(&self) -> bool {
        for i in 1..self.chain.len() {
            let current = &self.chain[i];
            let previous = &self.chain[i - 1];
            if current.hash != current.calculate_hash() {
                return false;
            }
            if current.previous_hash != previous.hash {
                return false;
            }
        }
        true
    }
}

fn current_timestamp() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis()
}

fn process_card_payment(card_number: &str, amount: f64) {
    println!("Visa/Mastercard payment processed: {} USD from {}", amount, card_number);
}

fn payout_salary(account: &str, amount: f64) {
    println!("Salary payout {} USD to {}", amount, account);
}

fn payout_business(account: &str, amount: f64) {
    println!("Business payout {} USD to {}", amount, account);
}

fn main() {
    let mut blockchain = Blockchain::new();

    blockchain.add_transaction(Transaction { sender: String::from("miner1"), recipient: String::from("worker1"), amount: 100.0, memo: String::from("Salary") });
    blockchain.mine_pending_transactions(String::from("miner1"));

    process_card_payment("4111111111111111", 150.0);
    payout_salary("worker1_wallet", 800.0);
    payout_business("business_wallet", 2000.0);

    println!("Chain valid: {}", blockchain.is_chain_valid());
}
