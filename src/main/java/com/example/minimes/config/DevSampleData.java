package com.example.minimes.config;

import com.example.minimes.item.ItemForm;
import com.example.minimes.item.ItemRepository;
import com.example.minimes.item.ItemService;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("dev")
public class DevSampleData implements CommandLineRunner {
    private final ItemRepository repository;
    private final ItemService service;

    public DevSampleData(ItemRepository repository, ItemService service) {
        this.repository = repository;
        this.service = service;
    }

    @Override
    public void run(String... args) {
        addIfMissing("DEMO-SHAFT-001", "구동축", "DEMO-DWG-001", "교육용 가상 품목. 선반 → 밀링 → 검사 공정 예정.");
        addIfMissing("DEMO-BRACKET-001", "고정 브래킷", "DEMO-DWG-002", "교육용 가상 품목. 밀링 → 검사 공정 예정.");
        addIfMissing("DEMO-BUSH-001", "가이드 부시", "DEMO-DWG-003", "교육용 가상 품목. 선반 → 검사 공정 예정.");
    }

    private void addIfMissing(String code, String name, String drawing, String description) {
        if (repository.existsByItemCode(code)) { return; }
        ItemForm form = new ItemForm();
        form.setItemCode(code);
        form.setItemName(name);
        form.setDrawingNumber(drawing);
        form.setDescription(description);
        service.create(form);
    }
}
