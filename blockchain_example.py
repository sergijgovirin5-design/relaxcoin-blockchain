import hashlib
import json
import time
from dataclasses import dataclass, asdict
from typing import List

@dataclass
class Transaction:
    sender: str
    recipient: str
    amount: float
    memo: str = ""

@dataclass
class Block:
    index: int
    timestamp: float
    transactions: List[Transaction]
    previous_hash: str
    nonce: int
    hash: str = ""

    def compute_hash(self):
        block_data = json.dumps({
            'index': self.index,
            'timestamp': self.timestamp,
            'transactions': [asdict(tx) for tx in self.transactions],
            'previous_hash': self.previous_hash,
            'nonce': self.nonce
        }, sort_keys=True)
        return hashlib.sha256(block_data.encode()).hexdigest()

class Blockchain:
    difficulty = 4

    def __init__(self):
        self.chain: List[Block] = []
        self.pending_transactions: List[Transaction] = []
        self.create_genesis_block()

    def create_genesis_block(self):
        genesis = Block(0, time.time(), [], "0", 0)
        genesis.hash = genesis.compute_hash()
        self.chain.append(genesis)

    def last_block(self):
        return self.chain[-1]

    def add_transaction(self, transaction: Transaction):
        self.pending_transactions.append(transaction)

    def mine_pending_transactions(self, miner_address: str):
        block = Block(
            index=len(self.chain),
            timestamp=time.time(),
            transactions=self.pending_transactions.copy(),
            previous_hash=self.last_block().hash,
            nonce=0
        )
        self.proof_of_work(block)
        self.chain.append(block)
        self.pending_transactions = [Transaction("SYSTEM", miner_address, 1.0, "block reward")]

    def proof_of_work(self, block: Block):
        target = '0' * self.difficulty
        while True:
            block.hash = block.compute_hash()
            if block.hash.startswith(target):
                return block.hash
            block.nonce += 1

    def is_chain_valid(self):
        for i in range(1, len(self.chain)):
            current = self.chain[i]
            previous = self.chain[i - 1]
            if current.hash != current.compute_hash():
                return False
            if current.previous_hash != previous.hash:
                return False
        return True

# Платёжные заглушки

def process_card_payment(card_number: str, amount: float):
    print(f"Processing Visa/Mastercard payment for {amount} USD from card {card_number}")
    return True


def payout_salary(payroll_account: str, amount: float):
    print(f"Payout salary {amount} USD to {payroll_account}")
    return True


def payout_business(owner_address: str, amount: float):
    print(f"Payout business profit {amount} USD to {owner_address}")
    return True

if __name__ == "__main__":
    chain = Blockchain()
    chain.add_transaction(Transaction("miner1", "worker1", 10.0, "salary"))
    chain.mine_pending_transactions("miner1")
    process_card_payment("4111111111111111", 100.0)
    payout_salary("worker1_wallet", 500.0)
    payout_business("business_wallet", 1200.0)
    print("Chain valid:", chain.is_chain_valid())
