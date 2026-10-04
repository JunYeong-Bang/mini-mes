package com.example.minimes.item;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;

public class ItemForm {
    @NotBlank(message = "품번을 입력해 주세요.")
    @Size(max = 50, message = "품번은 50자 이내로 입력해 주세요.")
    @Pattern(regexp = "[A-Z0-9][A-Z0-9._-]*", message = "품번은 영문·숫자로 시작하고 영문·숫자·점·밑줄·하이픈만 사용할 수 있습니다.")
    private String itemCode;

    @NotBlank(message = "품목명을 입력해 주세요.")
    @Size(max = 100, message = "품목명은 100자 이내로 입력해 주세요.")
    private String itemName;

    @Size(max = 100, message = "도면번호는 100자 이내로 입력해 주세요.")
    private String drawingNumber;

    @Size(max = 1000, message = "설명은 1,000자 이내로 입력해 주세요.")
    private String description;

    private boolean active = true;
    private Long version;

    public static ItemForm from(Item item) {
        ItemForm form = new ItemForm();
        form.setItemCode(item.getItemCode());
        form.setItemName(item.getItemName());
        form.setDrawingNumber(item.getDrawingNumber());
        form.setDescription(item.getDescription());
        form.setActive(item.isActive());
        form.setVersion(item.getVersion());
        return form;
    }

    private static String trim(String value) { return value == null ? null : value.strip(); }
    public String getItemCode() { return itemCode; }
    public void setItemCode(String value) { itemCode = value == null ? null : value.strip().toUpperCase(Locale.ROOT); }
    public String getItemName() { return itemName; }
    public void setItemName(String value) { itemName = trim(value); }
    public String getDrawingNumber() { return drawingNumber; }
    public void setDrawingNumber(String value) { drawingNumber = trim(value); }
    public String getDescription() { return description; }
    public void setDescription(String value) { description = trim(value); }
    public boolean isActive() { return active; }
    public void setActive(boolean value) { active = value; }
    public Long getVersion() { return version; }
    public void setVersion(Long value) { version = value; }
}
