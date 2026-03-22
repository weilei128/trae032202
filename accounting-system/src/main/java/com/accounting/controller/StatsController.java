package com.accounting.controller;

import com.accounting.common.BusinessException;
import com.accounting.common.Result;
import com.accounting.service.RecordService;
import com.accounting.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/stats")
public class StatsController {

    @Autowired
    private RecordService recordService;

    @Autowired
    private UserService userService;

    private Long getUserId(String token) {
        Long userId = userService.getUserIdByToken(token);
        if (userId == null) {
            throw new BusinessException(401, "请先登录");
        }
        return userId;
    }

    @GetMapping("/weekly")
    public Result<Map<String, Object>> getWeeklyStats(@RequestHeader("Authorization") String token) {
        Long userId = getUserId(token);
        Map<String, Object> stats = recordService.getWeeklyStats(userId);
        return Result.success(stats);
    }

    @GetMapping("/monthly")
    public Result<Map<String, Object>> getMonthlyStats(@RequestHeader("Authorization") String token) {
        Long userId = getUserId(token);
        Map<String, Object> stats = recordService.getMonthlyStats(userId);
        return Result.success(stats);
    }

    @GetMapping("/category")
    public Result<Map<String, Object>> getCategoryStats(@RequestHeader("Authorization") String token,
                                                        @RequestParam(required = false) String type) {
        Long userId = getUserId(token);
        Map<String, Object> stats = recordService.getCategoryStats(userId, type);
        return Result.success(stats);
    }
}
