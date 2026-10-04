package com.example.minimes.item;

public class DuplicateItemCodeException extends RuntimeException {
    public DuplicateItemCodeException() { super("이미 등록된 품번입니다. 다른 품번을 입력해 주세요."); }
}
