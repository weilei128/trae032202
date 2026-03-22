package com.accounting.dto;

import lombok.Data;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Pattern;

@Data
public class RegisterRequest {
    @NotBlank(message = "账号不能为空")
    @Pattern(regexp = "^(1[3-9]\\d{9})|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})$", 
             message = "账号格式不正确，请输入手机号或邮箱")
    private String account;

    @NotBlank(message = "密码不能为空")
    @Pattern(regexp = "^.{6,20}$", message = "密码长度必须在6-20位之间")
    private String password;

    private String nickname;
}
