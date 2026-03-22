package com.accounting.entity;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class User {
    private Long id;
    private String account;
    private String password;
    private String nickname;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
