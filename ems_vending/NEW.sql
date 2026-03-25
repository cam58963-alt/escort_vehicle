CREATE TABLE IF NOT EXISTS `vending_ems` (
    `machine_id` VARCHAR(64) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `stock` INT NOT NULL DEFAULT 0,
    `base_price` INT NOT NULL,
    `last_purchase` DATETIME NULL,
    PRIMARY KEY (`machine_id`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;