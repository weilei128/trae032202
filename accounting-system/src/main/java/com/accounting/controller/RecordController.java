package com.accounting.controller;

import com.accounting.common.BusinessException;
import com.accounting.common.Result;
import com.accounting.dto.AddRecordRequest;
import com.accounting.dto.RecordQueryRequest;
import com.accounting.dto.UpdateRecordRequest;
import com.accounting.entity.Record;
import com.accounting.service.RecordService;
import com.accounting.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/record")
public class RecordController {

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

    @PostMapping("/add")
    public Result<Record> addRecord(@RequestHeader("Authorization") String token,
                                    @Valid @RequestBody AddRecordRequest request) {
        Long userId = getUserId(token);
        Record record = recordService.addRecord(userId, request);
        return Result.success(record);
    }

    @PostMapping("/update")
    public Result<Record> updateRecord(@RequestHeader("Authorization") String token,
                                       @Valid @RequestBody UpdateRecordRequest request) {
        Long userId = getUserId(token);
        Record record = recordService.updateRecord(userId, request);
        return Result.success(record);
    }

    @DeleteMapping("/{id}")
    public Result<Void> deleteRecord(@RequestHeader("Authorization") String token,
                                     @PathVariable Long id) {
        Long userId = getUserId(token);
        recordService.deleteRecord(userId, id);
        return Result.success();
    }

    @GetMapping("/list")
    public Result<Map<String, Object>> queryRecords(@RequestHeader("Authorization") String token,
                                                    RecordQueryRequest request) {
        Long userId = getUserId(token);
        Map<String, Object> result = recordService.queryRecords(userId, request);
        return Result.success(result);
    }

    @GetMapping("/categories")
    public Result<Map<String, Object>> getCategories() {
        Map<String, Object> data = new HashMap<>();
        data.put("incomeCategories", RecordService.INCOME_CATEGORIES);
        data.put("expenseCategories", RecordService.EXPENSE_CATEGORIES);
        return Result.success(data);
    }
}
