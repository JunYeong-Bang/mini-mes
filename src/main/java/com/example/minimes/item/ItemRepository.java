package com.example.minimes.item;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ItemRepository extends JpaRepository<Item, Long> {
    boolean existsByItemCode(String itemCode);
    boolean existsByItemCodeAndIdNot(String itemCode, Long id);
    Page<Item> findByItemCodeContainingIgnoreCaseOrItemNameContainingIgnoreCase(String code, String name, Pageable pageable);
}
