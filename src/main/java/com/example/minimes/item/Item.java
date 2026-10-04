package com.example.minimes.item;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.time.ZoneId;

@Entity
@Table(name = "items", uniqueConstraints = @UniqueConstraint(name = "uc_items_item_code", columnNames = "item_code"))
public class Item {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "item_code", nullable = false, length = 50)
    private String itemCode;

    @Column(name = "item_name", nullable = false, length = 100)
    private String itemName;

    @Column(name = "drawing_number", length = 100)
    private String drawingNumber;

    @Column(length = 1000)
    private String description;

    @Column(nullable = false)
    private boolean active;

    @Version
    @Column(nullable = false)
    private Long version;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected Item() { }

    public Item(String itemCode, String itemName, String drawingNumber, String description, boolean active) {
        update(itemCode, itemName, drawingNumber, description, active);
    }

    public void update(String itemCode, String itemName, String drawingNumber, String description, boolean active) {
        this.itemCode = itemCode;
        this.itemName = itemName;
        this.drawingNumber = drawingNumber;
        this.description = description;
        this.active = active;
    }

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now(ZoneId.of("Asia/Seoul"));
        updatedAt = createdAt;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now(ZoneId.of("Asia/Seoul"));
    }

    public Long getId() { return id; }
    public String getItemCode() { return itemCode; }
    public String getItemName() { return itemName; }
    public String getDrawingNumber() { return drawingNumber; }
    public String getDescription() { return description; }
    public boolean isActive() { return active; }
    public Long getVersion() { return version; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
