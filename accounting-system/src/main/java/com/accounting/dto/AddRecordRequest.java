package com.accounting.dto;

import lombok.Data;
import javax.validation.constraints.*;
import java.math.BigDecimal;

@Data
public class AddRecordRequest {
    @NotNull(message = "金额不能为空")
    @Positive(message = "金额必须为正数")
    private BigDecimal amount;

    @NotBlank(message = "类型不能为空")
    @Pattern(regexp = "^(收入|支出)$", message = "类型必须为收入或支出")
    private String type;

    @NotBlank(message = "分类不能为空")
    private String category;

    private String remark;
}
