package com.accounting.service;

import com.accounting.common.BusinessException;
import com.accounting.dto.AddRecordRequest;
import com.accounting.dto.RecordQueryRequest;
import com.accounting.dto.UpdateRecordRequest;
import com.accounting.entity.Record;
import com.accounting.repository.RecordRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.WeekFields;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class RecordService {

    @Autowired
    private RecordRepository recordRepository;

    public static final List<String> INCOME_CATEGORIES = Arrays.asList("薪资", "奖金", "投资收益", "其他收入");
    public static final List<String> EXPENSE_CATEGORIES = Arrays.asList("餐饮", "购物", "交通", "娱乐", "医疗", "教育", "住房", "其他支出");

    public Record addRecord(Long userId, AddRecordRequest request) {
        validateCategory(request.getType(), request.getCategory());
        Record record = new Record();
        record.setUserId(userId);
        record.setAmount(request.getAmount());
        record.setType(request.getType());
        record.setCategory(request.getCategory());
        record.setRemark(request.getRemark());
        return recordRepository.save(record);
    }

    public Record updateRecord(Long userId, UpdateRecordRequest request) {
        Record record = recordRepository.findById(request.getId())
                .orElseThrow(() -> new BusinessException("记录不存在"));
        if (!record.getUserId().equals(userId)) {
            throw new BusinessException("无权修改此记录");
        }
        validateCategory(request.getType(), request.getCategory());
        record.setAmount(request.getAmount());
        record.setType(request.getType());
        record.setCategory(request.getCategory());
        record.setRemark(request.getRemark());
        return recordRepository.save(record);
    }

    public void deleteRecord(Long userId, Long recordId) {
        Record record = recordRepository.findById(recordId)
                .orElseThrow(() -> new BusinessException("记录不存在"));
        if (!record.getUserId().equals(userId)) {
            throw new BusinessException("无权删除此记录");
        }
        recordRepository.deleteById(recordId);
    }

    public Map<String, Object> queryRecords(Long userId, RecordQueryRequest request) {
        List<Record> records = recordRepository.findByUserId(userId);
        
        if (request.getStartDate() != null && !request.getStartDate().isEmpty()) {
            LocalDateTime start = LocalDate.parse(request.getStartDate()).atStartOfDay();
            records = records.stream().filter(r -> r.getCreateTime().isAfter(start) || r.getCreateTime().isEqual(start))
                    .collect(Collectors.toList());
        }
        if (request.getEndDate() != null && !request.getEndDate().isEmpty()) {
            LocalDateTime end = LocalDate.parse(request.getEndDate()).atTime(LocalTime.MAX);
            records = records.stream().filter(r -> r.getCreateTime().isBefore(end) || r.getCreateTime().isEqual(end))
                    .collect(Collectors.toList());
        }
        if (request.getType() != null && !request.getType().isEmpty()) {
            records = records.stream().filter(r -> r.getType().equals(request.getType()))
                    .collect(Collectors.toList());
        }
        if (request.getCategory() != null && !request.getCategory().isEmpty()) {
            records = records.stream().filter(r -> r.getCategory().equals(request.getCategory()))
                    .collect(Collectors.toList());
        }
        
        records.sort((a, b) -> b.getCreateTime().compareTo(a.getCreateTime()));
        
        int total = records.size();
        int page = request.getPage() != null ? request.getPage() : 1;
        int pageSize = request.getPageSize() != null ? request.getPageSize() : 10;
        int fromIndex = (page - 1) * pageSize;
        int toIndex = Math.min(fromIndex + pageSize, total);
        
        List<Record> pageRecords = fromIndex < total ? records.subList(fromIndex, toIndex) : new ArrayList<>();
        
        Map<String, Object> result = new HashMap<>();
        result.put("list", pageRecords);
        result.put("total", total);
        result.put("page", page);
        result.put("pageSize", pageSize);
        return result;
    }

    private void validateCategory(String type, String category) {
        if ("收入".equals(type)) {
            if (!INCOME_CATEGORIES.contains(category)) {
                throw new BusinessException("收入分类不正确，可选值：" + INCOME_CATEGORIES);
            }
        } else if ("支出".equals(type)) {
            if (!EXPENSE_CATEGORIES.contains(category)) {
                throw new BusinessException("支出分类不正确，可选值：" + EXPENSE_CATEGORIES);
            }
        }
    }

    public Map<String, Object> getWeeklyStats(Long userId) {
        List<Record> records = recordRepository.findByUserId(userId);
        LocalDate today = LocalDate.now();
        LocalDate startOfWeek = today.with(WeekFields.of(Locale.CHINA).dayOfWeek(), 1);
        LocalDate endOfWeek = startOfWeek.plusDays(6);
        
        return calculateStats(records, startOfWeek.atStartOfDay(), endOfWeek.atTime(LocalTime.MAX));
    }

    public Map<String, Object> getMonthlyStats(Long userId) {
        List<Record> records = recordRepository.findByUserId(userId);
        LocalDate today = LocalDate.now();
        LocalDate startOfMonth = today.withDayOfMonth(1);
        LocalDate endOfMonth = today.withDayOfMonth(today.lengthOfMonth());
        
        return calculateStats(records, startOfMonth.atStartOfDay(), endOfMonth.atTime(LocalTime.MAX));
    }

    private Map<String, Object> calculateStats(List<Record> records, LocalDateTime start, LocalDateTime end) {
        List<Record> filteredRecords = records.stream()
                .filter(r -> (r.getCreateTime().isAfter(start) || r.getCreateTime().isEqual(start)) &&
                            (r.getCreateTime().isBefore(end) || r.getCreateTime().isEqual(end)))
                .collect(Collectors.toList());
        
        double totalIncome = filteredRecords.stream()
                .filter(r -> "收入".equals(r.getType()))
                .mapToDouble(r -> r.getAmount().doubleValue())
                .sum();
        
        double totalExpense = filteredRecords.stream()
                .filter(r -> "支出".equals(r.getType()))
                .mapToDouble(r -> r.getAmount().doubleValue())
                .sum();
        
        Map<String, Object> result = new HashMap<>();
        result.put("totalIncome", totalIncome);
        result.put("totalExpense", totalExpense);
        result.put("balance", totalIncome - totalExpense);
        return result;
    }

    public Map<String, Object> getCategoryStats(Long userId, String type) {
        List<Record> records = recordRepository.findByUserId(userId);
        
        Map<String, Double> categoryTotals = records.stream()
                .filter(r -> type == null || type.isEmpty() || r.getType().equals(type))
                .collect(Collectors.groupingBy(Record::getCategory, 
                        Collectors.summingDouble(r -> r.getAmount().doubleValue())));
        
        double total = categoryTotals.values().stream().mapToDouble(Double::doubleValue).sum();
        
        List<Map<String, Object>> categoryList = new ArrayList<>();
        for (Map.Entry<String, Double> entry : categoryTotals.entrySet()) {
            Map<String, Object> item = new HashMap<>();
            item.put("category", entry.getKey());
            item.put("amount", entry.getValue());
            item.put("percentage", total > 0 ? String.format("%.2f", entry.getValue() / total * 100) : "0.00");
            categoryList.add(item);
        }
        
        categoryList.sort((a, b) -> Double.compare((Double) b.get("amount"), (Double) a.get("amount")));
        
        Map<String, Object> result = new HashMap<>();
        result.put("list", categoryList);
        result.put("total", total);
        return result;
    }
}
