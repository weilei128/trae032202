package com.accounting.dto;

import lombok.Data;

@Data
public class RecordQueryRequest {
    private String startDate;
    private String endDate;
    private String type;
    private String category;
    private Integer page = 1;
    private Integer pageSize = 10;
}
