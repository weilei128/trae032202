package com.accounting.entity;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class Record {
    private Long id;
    private Long userId;
    private BigDecimal amount;
    private String type;
    private String category;
    private String remark;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
