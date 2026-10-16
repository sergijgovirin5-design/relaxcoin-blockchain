package main

import (
    "crypto/sha256"
    "encoding/hex"
    "testing"
)

func TestAddTransaction_Success(t *testing.T) {
    bc := Blockchain{Chain: []Block{createGenesisBlock()}, Difficulty: 1}
    err := bc.AddTransaction(Transaction{Sender: "alice", Recipient: "bob", Amount: 10.0, Memo: "payment"})
    if err != nil {
        t.Fatalf("expected no error, got %v", err)
    }
    if len(bc.PendingTransactions) != 1 {
        t.Fatalf("expected 1 pending transaction, got %d", len(bc.PendingTransactions))
    }
}

func TestAddTransaction_InvalidAmount(t *testing.T) {
    bc := Blockchain{Chain: []Block{createGenesisBlock()}, Difficulty: 1}
    err := bc.AddTransaction(Transaction{Sender: "alice", Recipient: "bob", Amount: 0, Memo: "payment"})
    if err == nil {
        t.Fatal("expected error for zero amount, got nil")
    }
}

func TestAddTransaction_MissingFields(t *testing.T) {
    bc := Blockchain{Chain: []Block{createGenesisBlock()}, Difficulty: 1}
    err := bc.AddTransaction(Transaction{Sender: "", Recipient: "bob", Amount: 5.0, Memo: "payment"})
    if err == nil {
        t.Fatal("expected error for missing sender, got nil")
    }

    err = bc.AddTransaction(Transaction{Sender: "alice", Recipient: "", Amount: 5.0, Memo: "payment"})
    if err == nil {
        t.Fatal("expected error for missing recipient, got nil")
    }
}

func TestVerifyTransactionSignature(t *testing.T) {
    tx := Transaction{Sender: "alice", Recipient: "bob", Amount: 12.5, Memo: "invoice"}
    expectedHash := sha256.Sum256([]byte("alice:bob:12.500000"))
    sig := hex.EncodeToString(expectedHash[:])

    if !VerifyTransactionSignature(tx, sig) {
        t.Fatal("expected valid signature")
    }

    if VerifyTransactionSignature(tx, "invalidsignature") {
        t.Fatal("expected invalid signature to be rejected")
    }
}

func TestMinePendingTransactionsAndChainValid(t *testing.T) {
    bc := Blockchain{Chain: []Block{createGenesisBlock()}, Difficulty: 1}
    err := bc.AddTransaction(Transaction{Sender: "alice", Recipient: "bob", Amount: 2.5, Memo: "tip"})
    if err != nil {
        t.Fatalf("unexpected error adding transaction: %v", err)
    }

    bc.minePendingTransactions("miner1")
    if len(bc.Chain) != 2 {
        t.Fatalf("expected chain length 2, got %d", len(bc.Chain))
    }
    if !bc.isChainValid() {
        t.Fatal("expected chain to be valid after mining")
    }
}

func TestChainInvalidAfterTampering(t *testing.T) {
    bc := Blockchain{Chain: []Block{createGenesisBlock()}, Difficulty: 1}
    err := bc.AddTransaction(Transaction{Sender: "alice", Recipient: "bob", Amount: 2.5, Memo: "tip"})
    if err != nil {
        t.Fatalf("unexpected error adding transaction: %v", err)
    }
    bc.minePendingTransactions("miner1")

    bc.Chain[1].Transactions[0].Amount = 999.9
    if bc.isChainValid() {
        t.Fatal("expected chain to be invalid after tampering")
    }
}

func TestPaymentPayoutHelpers(t *testing.T) {
    if !processCardPayment("4111111111111111", 50.0) {
        t.Fatal("expected processCardPayment to return true")
    }
    if !payoutSalary("worker1_wallet", 1200.0) {
        t.Fatal("expected payoutSalary to return true")
    }
    if !payoutBusiness("business_wallet", 3000.0) {
        t.Fatal("expected payoutBusiness to return true")
    }
}
