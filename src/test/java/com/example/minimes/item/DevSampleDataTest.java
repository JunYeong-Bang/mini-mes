package com.example.minimes.item;

import com.example.minimes.config.DevSampleData;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:devseed;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1")
@ActiveProfiles({"test", "dev"})
class DevSampleDataTest {
    @Autowired ItemService service;
    @Autowired ItemRepository repository;
    @Autowired DevSampleData sampleData;

    @Test
    void seedsOnlyMissingItemsAndNeverOverwritesEdits() {
        assertThat(repository.count()).isEqualTo(3);
        Item item = service.findItems("DEMO-SHAFT-001", 0).getContent().getFirst();
        ItemForm edit = ItemForm.from(item);
        edit.setItemName("직접 수정한 구동축");
        edit.setActive(false);
        service.update(item.getId(), edit);
        sampleData.run();
        assertThat(repository.count()).isEqualTo(3);
        assertThat(service.getItem(item.getId()).getItemName()).isEqualTo("직접 수정한 구동축");
        assertThat(service.getItem(item.getId()).isActive()).isFalse();
    }
}
