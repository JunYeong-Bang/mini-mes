package com.example.minimes.item;

import jakarta.validation.Valid;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import java.util.Objects;

@Service
@Validated
@Transactional(readOnly = true)
public class ItemService {
    private final ItemRepository repository;

    public ItemService(ItemRepository repository) { this.repository = repository; }

    public Page<Item> findItems(String keyword, int page) {
        var pageable = PageRequest.of(Math.max(page, 0), 20, Sort.by("id").descending());
        String query = keyword == null ? "" : keyword.strip();
        if (query.isEmpty()) { return repository.findAll(pageable); }
        return repository.findByItemCodeContainingIgnoreCaseOrItemNameContainingIgnoreCase(query, query, pageable);
    }

    public Item getItem(Long id) {
        return repository.findById(id).orElseThrow(ItemNotFoundException::new);
    }

    @Transactional
    public Long create(@Valid ItemForm form) {
        if (repository.existsByItemCode(form.getItemCode())) { throw new DuplicateItemCodeException(); }
        Item item = new Item(form.getItemCode(), form.getItemName(), form.getDrawingNumber(), form.getDescription(), form.isActive());
        // flush로 고유 제약 오류를 화면 요청이 끝나기 전에 확인한다.
        return repository.saveAndFlush(item).getId();
    }

    @Transactional
    public void update(Long id, @Valid ItemForm form) {
        Item item = getItem(id);
        if (!Objects.equals(item.getVersion(), form.getVersion())) {
            throw new OptimisticLockingFailureException("다른 수정이 먼저 저장되었습니다. 목록에서 수정 화면을 다시 열어 주세요.");
        }
        if (repository.existsByItemCodeAndIdNot(form.getItemCode(), id)) { throw new DuplicateItemCodeException(); }
        item.update(form.getItemCode(), form.getItemName(), form.getDrawingNumber(), form.getDescription(), form.isActive());
        repository.flush();
    }
}
