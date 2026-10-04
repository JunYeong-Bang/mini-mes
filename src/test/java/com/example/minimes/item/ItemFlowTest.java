package com.example.minimes.item;

import com.example.minimes.config.DevSampleData;
import jakarta.validation.ConstraintViolationException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.ApplicationContext;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class ItemFlowTest {
    @Autowired MockMvc mvc;
    @Autowired ItemRepository repository;
    @Autowired ItemService service;
    @Autowired ApplicationContext context;

    private String uniqueCode() { return "T-" + UUID.randomUUID().toString().toUpperCase(); }

    private ItemForm form(String code, String name) {
        ItemForm form = new ItemForm();
        form.setItemCode(code);
        form.setItemName(name);
        return form;
    }

    @Test
    void rendersHomeListAndRegistrationFormWithoutDevSeed() throws Exception {
        assertThat(context.getBeansOfType(DevSampleData.class)).isEmpty();
        mvc.perform(get("/")).andExpect(status().is3xxRedirection()).andExpect(redirectedUrl("/items"));
        mvc.perform(get("/items")).andExpect(status().isOk()).andExpect(content().string(containsString("품목 관리")));
        mvc.perform(get("/items/new")).andExpect(status().isOk()).andExpect(content().string(containsString("품목 등록")));
        mvc.perform(get("/vendor/bootstrap.min.css")).andExpect(status().isOk());
    }

    @Test
    void createsNormalizedItemThroughControllerAndSearchesIt() throws Exception {
        String code = uniqueCode();
        mvc.perform(post("/items").param("itemCode", " " + code.toLowerCase() + " ")
                .param("itemName", " 구동축 ").param("drawingNumber", " DWG-100 ")
                .param("description", " 선반 가공 ").param("active", "true"))
                .andExpect(status().is3xxRedirection()).andExpect(redirectedUrl("/items"));
        Item item = service.findItems(code, 0).getContent().getFirst();
        assertThat(item.getItemCode()).isEqualTo(code);
        assertThat(item.getItemName()).isEqualTo("구동축");
        assertThat(item.getDrawingNumber()).isEqualTo("DWG-100");
        assertThat(item.getCreatedAt()).isNotNull();
        mvc.perform(get("/items").param("q", code.toLowerCase())).andExpect(status().isOk())
                .andExpect(content().string(containsString(code)));
    }

    @Test
    void rejectsBlankRequiredFieldsWithoutSaving() throws Exception {
        long before = repository.count();
        mvc.perform(post("/items").param("itemCode", "   ").param("itemName", "  "))
                .andExpect(status().isOk()).andExpect(model().attributeHasFieldErrors("itemForm", "itemCode", "itemName"))
                .andExpect(content().string(containsString("품목명을 입력해 주세요.")));
        assertThat(repository.count()).isEqualTo(before);
    }

    @Test
    void rejectsOversizedFieldsAndInvalidCode() throws Exception {
        mvc.perform(post("/items").param("itemCode", "X".repeat(51)).param("itemName", "가".repeat(101))
                .param("drawingNumber", "D".repeat(101)).param("description", "설".repeat(1001)))
                .andExpect(status().isOk()).andExpect(model().attributeHasFieldErrors("itemForm", "itemCode", "itemName", "drawingNumber", "description"));
        mvc.perform(post("/items").param("itemCode", "한글 품번").param("itemName", "가공품"))
                .andExpect(model().attributeHasFieldErrors("itemForm", "itemCode"));
    }

    @Test
    void rejectsDuplicateCreateIncludingLowercase() throws Exception {
        String code = uniqueCode();
        service.create(form(code, "기존 품목"));
        mvc.perform(post("/items").param("itemCode", code.toLowerCase()).param("itemName", "중복 품목"))
                .andExpect(status().isOk()).andExpect(model().attributeHasFieldErrors("itemForm", "itemCode"))
                .andExpect(content().string(containsString("이미 등록된 품번")));
        assertThat(service.findItems(code, 0).getTotalElements()).isEqualTo(1);
    }

    @Test
    void databaseUniqueConstraintRejectsBypassingService() {
        String code = uniqueCode();
        service.create(form(code, "원본"));
        assertThatThrownBy(() -> repository.saveAndFlush(new Item(code, "중복", null, null, true)))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThat(service.findItems(code, 0).getTotalElements()).isEqualTo(1);
    }

    @Test
    void updatesSameCodeAndDeactivatesWithoutDeleting() throws Exception {
        String code = uniqueCode();
        Long id = service.create(form(code, "수정 전"));
        Item before = service.getItem(id);
        mvc.perform(get("/items/{id}/edit", id)).andExpect(status().isOk())
                .andExpect(content().string(containsString("수정 전")));
        mvc.perform(post("/items/{id}", id).param("itemCode", code).param("itemName", "수정 후")
                .param("_active", "on").param("version", before.getVersion().toString()))
                .andExpect(status().is3xxRedirection());
        Item after = service.getItem(id);
        assertThat(after.getItemName()).isEqualTo("수정 후");
        assertThat(after.isActive()).isFalse();
        assertThat(after.getCreatedAt()).isEqualTo(before.getCreatedAt());
        assertThat(after.getVersion()).isGreaterThan(before.getVersion());
        assertThat(repository.existsById(id)).isTrue();
    }

    @Test
    void rejectsDuplicateEditAndPreservesOriginal() throws Exception {
        String firstCode = uniqueCode();
        String secondCode = uniqueCode();
        service.create(form(firstCode, "첫 품목"));
        Long id = service.create(form(secondCode, "둘째 품목"));
        mvc.perform(post("/items/{id}", id).param("itemCode", firstCode).param("itemName", "충돌")
                .param("version", service.getItem(id).getVersion().toString()))
                .andExpect(status().isOk()).andExpect(model().attributeHasFieldErrors("itemForm", "itemCode"));
        assertThat(service.getItem(id).getItemCode()).isEqualTo(secondCode);
    }

    @Test
    void rejectsStaleAndMissingVersionWithoutOverwriting() throws Exception {
        String code = uniqueCode();
        Long id = service.create(form(code, "최초"));
        Long oldVersion = service.getItem(id).getVersion();
        ItemForm update = ItemForm.from(service.getItem(id));
        update.setItemName("먼저 저장한 내용");
        service.update(id, update);
        mvc.perform(post("/items/{id}", id).param("itemCode", code).param("itemName", "오래된 화면")
                .param("version", oldVersion.toString())).andExpect(status().isOk())
                .andExpect(model().attributeHasErrors("itemForm"))
                .andExpect(content().string(containsString("다른 수정이 먼저 저장되었습니다")));
        mvc.perform(post("/items/{id}", id).param("itemCode", code).param("itemName", "버전 누락"))
                .andExpect(model().attributeHasErrors("itemForm"));
        assertThat(service.getItem(id).getItemName()).isEqualTo("먼저 저장한 내용");
    }

    @Test
    void missingItemReturns404() throws Exception {
        mvc.perform(get("/items/9223372036854775807/edit")).andExpect(status().isNotFound());
        mvc.perform(post("/items/9223372036854775807").param("itemCode", uniqueCode())
                .param("itemName", "없는 품목").param("version", "0")).andExpect(status().isNotFound());
    }

    @Test
    void rendersUserTextEscapedAndSupportsPagination() throws Exception {
        String code = uniqueCode();
        service.create(form(code, "<script>alert('x')</script>"));
        mvc.perform(get("/items").param("q", code)).andExpect(status().isOk())
                .andExpect(content().string(containsString("&lt;script&gt;")))
                .andExpect(content().string(not(containsString("<script>alert"))));
        String group = "PAGE-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        for (int i = 0; i < 21; i++) { service.create(form(group + "-" + i, "페이징 품목")); }
        assertThat(service.findItems(group, 0).getContent()).hasSize(20);
        assertThat(service.findItems(group, 1).getContent()).hasSize(1);
        mvc.perform(get("/items").param("q", group)).andExpect(status().isOk())
                .andExpect(content().string(containsString("다음")));
        mvc.perform(get("/items").param("q", group).param("page", "1")).andExpect(status().isOk())
                .andExpect(content().string(containsString("이전")));
    }

    @Test
    void serviceAlsoValidatesRequiredFields() {
        assertThatThrownBy(() -> service.create(new ItemForm())).isInstanceOf(ConstraintViolationException.class);
    }
}
