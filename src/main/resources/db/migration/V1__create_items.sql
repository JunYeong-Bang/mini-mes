CREATE TABLE items (
    id BIGINT NOT NULL AUTO_INCREMENT,
    item_code VARCHAR(50) NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    drawing_number VARCHAR(100),
    description VARCHAR(1000),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uc_items_item_code UNIQUE (item_code),
    CONSTRAINT ck_items_code_not_blank CHECK (CHAR_LENGTH(TRIM(item_code)) > 0),
    CONSTRAINT ck_items_name_not_blank CHECK (CHAR_LENGTH(TRIM(item_name)) > 0)
);
