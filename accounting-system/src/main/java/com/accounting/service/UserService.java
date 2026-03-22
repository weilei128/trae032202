package com.accounting.service;

import com.accounting.common.BusinessException;
import com.accounting.dto.ChangePasswordRequest;
import com.accounting.dto.LoginRequest;
import com.accounting.dto.RegisterRequest;
import com.accounting.entity.User;
import com.accounting.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;

    private final Map<String, Long> tokenStore = new HashMap<>();

    public void register(RegisterRequest request) {
        if (userRepository.findByAccount(request.getAccount()).isPresent()) {
            throw new BusinessException("账号已存在");
        }
        User user = new User();
        user.setAccount(request.getAccount());
        user.setPassword(request.getPassword());
        user.setNickname(request.getNickname() != null ? request.getNickname() : request.getAccount());
        userRepository.save(user);
    }

    public String login(LoginRequest request) {
        User user = userRepository.findByAccount(request.getAccount())
                .orElseThrow(() -> new BusinessException("账号或密码错误"));
        if (!user.getPassword().equals(request.getPassword())) {
            throw new BusinessException("账号或密码错误");
        }
        String token = UUID.randomUUID().toString().replace("-", "");
        tokenStore.put(token, user.getId());
        return token;
    }

    public void changePassword(Long userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("用户不存在"));
        if (!user.getPassword().equals(request.getOldPassword())) {
            throw new BusinessException("原密码错误");
        }
        user.setPassword(request.getNewPassword());
        userRepository.save(user);
    }

    public Long getUserIdByToken(String token) {
        if (token == null || !tokenStore.containsKey(token)) {
            return null;
        }
        return tokenStore.get(token);
    }

    public User getUserById(Long id) {
        return userRepository.findById(id).orElse(null);
    }
}
