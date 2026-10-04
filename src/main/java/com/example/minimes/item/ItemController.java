package com.example.minimes.item;

import jakarta.validation.Valid;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.WebDataBinder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import java.util.Locale;

@Controller
@RequestMapping("/items")
public class ItemController {
    private final ItemService service;

    public ItemController(ItemService service) { this.service = service; }

    @InitBinder("itemForm")
    void allowFormFields(WebDataBinder binder) {
        binder.setAllowedFields("itemCode", "itemName", "drawingNumber", "description", "active", "_active", "version");
    }

    @GetMapping
    public String list(@RequestParam(defaultValue = "") String q, @RequestParam(defaultValue = "0") int page, Model model) {
        model.addAttribute("items", service.findItems(q, page));
        model.addAttribute("q", q);
        return "items/list";
    }

    @GetMapping("/new")
    public String newForm(Model model) {
        model.addAttribute("itemForm", new ItemForm());
        return form(model, null);
    }

    @PostMapping
    public String create(@Valid @ModelAttribute ItemForm itemForm, BindingResult errors, Model model, RedirectAttributes redirect) {
        if (errors.hasErrors()) { return form(model, null); }
        try {
            service.create(itemForm);
        } catch (DuplicateItemCodeException e) {
            errors.rejectValue("itemCode", "duplicate", e.getMessage());
            return form(model, null);
        } catch (DataIntegrityViolationException e) {
            rejectDatabaseConflict(errors, e);
            return form(model, null);
        }
        redirect.addFlashAttribute("message", "품목을 등록했습니다.");
        return "redirect:/items";
    }

    @GetMapping("/{id}/edit")
    public String editForm(@PathVariable Long id, Model model) {
        model.addAttribute("itemForm", ItemForm.from(service.getItem(id)));
        return form(model, id);
    }

    @PostMapping("/{id}")
    public String update(@PathVariable Long id, @Valid @ModelAttribute ItemForm itemForm, BindingResult errors, Model model, RedirectAttributes redirect) {
        if (errors.hasErrors()) { return form(model, id); }
        try {
            service.update(id, itemForm);
        } catch (DuplicateItemCodeException e) {
            errors.rejectValue("itemCode", "duplicate", e.getMessage());
            return form(model, id);
        } catch (OptimisticLockingFailureException e) {
            errors.reject("stale", "다른 수정이 먼저 저장되었습니다. 목록에서 수정 화면을 다시 열어 주세요.");
            return form(model, id);
        } catch (DataIntegrityViolationException e) {
            rejectDatabaseConflict(errors, e);
            return form(model, id);
        }
        redirect.addFlashAttribute("message", "품목을 수정했습니다.");
        return "redirect:/items";
    }

    private String form(Model model, Long id) {
        model.addAttribute("itemId", id);
        model.addAttribute("pageTitle", id == null ? "품목 등록" : "품목 수정");
        return "items/form";
    }

    private void rejectDatabaseConflict(BindingResult errors, DataIntegrityViolationException exception) {
        // 사전 조회 후 다른 요청이 같은 품번을 저장할 수도 있으므로 DB 제약도 처리한다.
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause.getMessage() != null && cause.getMessage().toLowerCase(Locale.ROOT).contains("uc_items_item_code")) {
                errors.rejectValue("itemCode", "duplicate", "이미 등록된 품번입니다. 다른 품번을 입력해 주세요.");
                return;
            }
        }
        errors.reject("conflict", "입력값이 DB 규칙과 충돌했습니다. 입력 내용을 확인해 주세요.");
    }
}
