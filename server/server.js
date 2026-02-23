// ================= IMPORTS =================
const express = require("express");
const mysql = require("mysql2");
const bcrypt = require("bcrypt");
const bodyParser = require("body-parser");
const cors = require("cors");
const nodemailer = require("nodemailer");
const twilio = require("twilio");
const multer = require('multer');
const FormData = require('form-data');
const axios = require('axios');
const pdfParse = require('pdf-parse');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');


// ================= APP SETUP =================
const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(express.raw({ limit: '50mb' }));
app.use(express.text({ limit: '50mb' }));

// Add this right after app.use(bodyParser.json());
app.get('/', (req, res) => {
  res.json({ message: 'Server is running!' });
});

// ================= MYSQL CONNECTION =================
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "campus entry guide",
});

db.connect((err) => {
  if (err) {
    console.error("❌ MySQL Connection Error:", err);
    return;
  }
  console.log("✅ MySQL Connected!");
});

// ================= HELPER FUNCTIONS =================
const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(10);
  return await bcrypt.hash(password, salt);
};

const generateOtp = () => Math.floor(100000 + Math.random() * 900000).toString();

const getTableByRole = (role) => {
  if (role === "Student") return "student_registration";
  if (role === "Teacher") return "teacher_registration";
  if (role === "Admin") return "admin_registration";
  return null;
};

// ================= EMAIL TRANSPORTER =================
const mailTransporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "qabqbdul@gmail.com",
    pass: "ivfk gjss xzuc wfix",
  },
});


const checkEmailExists = (email) => {
  const tables = [
    "student_registration",
    "teacher_registration",
    "admin_registration"
  ];

  return new Promise((resolve, reject) => {
    let found = false;
    let checked = 0;

    tables.forEach((table) => {
      db.query(`SELECT * FROM ${table} WHERE email=? LIMIT 1`, [email], (err, results) => {
        checked++;
        if (err) return reject(err);

        if (results.length > 0) {
          found = true;
        }

        if (checked === tables.length) {
          resolve(found);
        }
      });
    });
  });
};


// ================= REGISTER ENDPOINT =================
app.post("/register", async (req, res) => {
  const { role, full_name, email, password } = req.body;

  if (!role || !full_name || !email || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  try {
    // ✅ Check if email already exists in any table
    const exists = await checkEmailExists(email);
    if (exists) {
      return res.status(400).json({ message: "Email already exists. Please use a different email." });
    }

    const hashedPassword = await hashPassword(password);

    let sql, values;

    if (role === "Student") {
      const arid_no = req.body.arid_no || null;
      const degree = req.body.degree || null;
      const semester_no = req.body.semester_no || null;
      const section = req.body.section || null;
      const phone_number = req.body.phone_number || null;

      sql = `INSERT INTO student_registration
             (full_name, arid_no, degree, semester_no, section, email, phone_number, password)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
      values = [full_name, arid_no, degree, semester_no, section, email, phone_number, hashedPassword];

    } else if (role === "Teacher") {
      const department = req.body.department || null;
      const subject_name = req.body.subject_name || null;
      const shift = req.body.shift || null;
      const phone_number = req.body.phone_number || null;

      sql = `INSERT INTO teacher_registration
             (full_name, department, subject_name, shift, email, phone_number, password)
             VALUES (?, ?, ?, ?, ?, ?, ?)`;
      values = [full_name, department, subject_name, shift, email, phone_number, hashedPassword];

    } else if (role === "Admin") {
      const department = req.body.department || null;
      const admin_id = req.body.admin_id || null;
      const office_name = req.body.office_name || null;
      const phone_number = req.body.phone_number || null;

      sql = `INSERT INTO admin_registration
             (full_name, department, admin_id, office_name, email, phone_number, password)
             VALUES (?, ?, ?, ?, ?, ?, ?)`;
      values = [full_name, department, admin_id, office_name, email, phone_number, hashedPassword];

    } else {
      return res.status(400).json({ message: "Invalid role" });
    }

    db.query(sql, values, (err, result) => {
      if (err) {
        console.error("Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }
      return res.status(201).json({ message: `${role} registered successfully!` });
    });
  } catch (error) {
    console.error("Server Error:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

// ================= LOGIN ENDPOINT =================
app.post("/login", async (req, res) => {
  const { role, email, password } = req.body;

  if (!role || !email || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  let table;
  if (role === "Student") table = "student_registration";
  else if (role === "Teacher") table = "teacher_registration";
  else if (role === "Admin") table = "admin_registration";
  else return res.status(400).json({ message: "Invalid role" });

  const sql = `SELECT * FROM ${table} WHERE email = ? LIMIT 1`;
  db.query(sql, [email], async (err, results) => {
    if (err) {
      console.error("Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(401).json({ message: "Email not found" });
    }

    const user = results[0];
    const match = await bcrypt.compare(password, user.password);

    if (!match) {
      return res.status(401).json({ message: "Incorrect password" });
    }

    // ✅ Build complete user response based on role
    let userResponse = {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      role: role,
      phone_number: user.phone_number || null,
    };

    // ✅ Add role-specific fields
    if (role === "Student") {
      userResponse.arid_no = user.arid_no || null;
      userResponse.degree = user.degree || null;
      userResponse.semester_no = user.semester_no || null;
      userResponse.section = user.section || null;
    } else if (role === "Teacher") {
      userResponse.department = user.department || null;
      userResponse.subject_name = user.subject_name || null;
      userResponse.shift = user.shift || null;
    } else if (role === "Admin") {
      userResponse.department = user.department || null;
      userResponse.admin_id = user.admin_id || null;
      userResponse.office_name = user.office_name || null;
    }

    console.log(`✅ ${role} logged in:`, userResponse);

    return res.status(200).json({
      message: `${role} logged in successfully`,
      user: userResponse,
    });
  });
});

// ================= UPDATE USER PROFILE ENDPOINT (ADD THIS TO YOUR SERVER.JS) =================
app.post("/update-user-profile", async (req, res) => {
  const { userId, role } = req.body;

  console.log("📝 Profile Update Request - User ID:", userId, "Role:", role);

  if (!userId || !role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const table = getTableByRole(role);
  if (!table) {
    return res.status(400).json({ message: "Invalid role" });
  }

  try {
    // Common fields
    let updateFields = [];
    let updateValues = [];

    // Full Name
    if (req.body.full_name) {
      updateFields.push("full_name = ?");
      updateValues.push(req.body.full_name);
    }

    // Phone Number
    if (req.body.phone_number) {
      updateFields.push("phone_number = ?");
      updateValues.push(req.body.phone_number);
    }

    // Department
    if (req.body.department) {
      updateFields.push("department = ?");
      updateValues.push(req.body.department);
    }

    // Profile Image
    if (req.body.profile_image !== undefined) {
      updateFields.push("profile_image = ?");
      updateValues.push(req.body.profile_image);
    }

    // Role-specific fields
    if (role === "Student") {
      if (req.body.arid_no) {
        updateFields.push("arid_no = ?");
        updateValues.push(req.body.arid_no);
      }
      if (req.body.degree) {
        updateFields.push("degree = ?");
        updateValues.push(req.body.degree);
      }
      if (req.body.semester_no) {
        updateFields.push("semester_no = ?");
        updateValues.push(req.body.semester_no);
      }
      if (req.body.section) {
        updateFields.push("section = ?");
        updateValues.push(req.body.section);
      }
    } else if (role === "Teacher") {
      if (req.body.subject_name) {
        updateFields.push("subject_name = ?");
        updateValues.push(req.body.subject_name);
      }
      if (req.body.shift) {
        updateFields.push("shift = ?");
        updateValues.push(req.body.shift);
      }
    } else if (role === "Admin") {
      if (req.body.admin_id) {
        updateFields.push("admin_id = ?");
        updateValues.push(req.body.admin_id);
      }
      if (req.body.office_name) {
        updateFields.push("office_name = ?");
        updateValues.push(req.body.office_name);
      }
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    // Add userId to the end for WHERE clause
    updateValues.push(userId);

    const sql = `UPDATE ${table} SET ${updateFields.join(", ")} WHERE id = ?`;

    console.log("🔄 SQL Query:", sql);
    console.log("🔄 Values:", updateValues);

    db.query(sql, updateValues, (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      if (result.affectedRows === 0) {
        console.log("❌ User not found for ID:", userId);
        return res.status(404).json({ message: "User not found" });
      }

      console.log("✅ Profile updated successfully for User ID:", userId);

      res.status(200).json({
        message: "Profile updated successfully",
        affectedRows: result.affectedRows,
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// ================= ALSO UPDATE THE GET PROFILE ENDPOINT TO INCLUDE profile_image =================
// Replace your existing /get-user-profile endpoint with this updated version:

app.post("/get-user-profile", (req, res) => {
  const { userId, role } = req.body;

  console.log("📋 Profile Request - User ID:", userId, "Role:", role);

  if (!userId || !role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const table = getTableByRole(role);
  if (!table) {
    return res.status(400).json({ message: "Invalid role" });
  }

  const sql = `SELECT * FROM ${table} WHERE id = ? LIMIT 1`;
  
  db.query(sql, [userId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      console.log("❌ User not found for ID:", userId);
      return res.status(404).json({ message: "User not found" });
    }

    const user = results[0];
    console.log("✅ User found:", user.full_name);

    // Remove sensitive data
    delete user.password;
    delete user.otp;
    delete user.otp_expiry;

    // Format response based on role
    let profileData = {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone_number: user.phone_number || "Not provided",
      role: role,
      profile_image: user.profile_image || null, // ← Added this line
    };

    if (role === "Student") {
      profileData.arid_no = user.arid_no || "Not assigned";
      profileData.degree = user.degree || "Not assigned";
      profileData.semester = user.semester_no || "Not assigned";
      profileData.section = user.section || "Not assigned";
      // profileData.department = user.degree || "Not assigned";
    } else if (role === "Teacher") {
      profileData.department = user.department || "Not assigned";
      profileData.subject_name = user.subject_name || "Not assigned";
      profileData.shift = user.shift || "Not assigned";
    } else if (role === "Admin") {
      profileData.department = user.department || "Not assigned";
      profileData.admin_id = user.admin_id || "Not assigned";
      profileData.office_name = user.office_name || "Not assigned";
    }

    res.status(200).json({
      message: "Profile retrieved successfully",
      userData: profileData
    });
  });
});

// ================= CHANGE PASSWORD ENDPOINT =================
app.post("/change-password", async (req, res) => {
  const { userId, role, email, currentPassword, newPassword } = req.body;

  console.log("🔐 Change Password Request - User ID:", userId, "Role:", role);

  if (!userId || !role || !email || !currentPassword || !newPassword) {
    return res.status(400).json({ message: "All fields are required" });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ message: "New password must be at least 6 characters" });
  }

  const table = getTableByRole(role);
  if (!table) {
    return res.status(400).json({ message: "Invalid role" });
  }

  try {
    // Get user from database
    const sql = `SELECT * FROM ${table} WHERE id = ? AND email = ? LIMIT 1`;
    
    db.query(sql, [userId, email], async (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      if (results.length === 0) {
        console.log("❌ User not found for ID:", userId);
        return res.status(404).json({ message: "User not found" });
      }

      const user = results[0];

      // Verify current password
      const match = await bcrypt.compare(currentPassword, user.password);
      if (!match) {
        console.log("❌ Current password is incorrect");
        return res.status(401).json({ message: "Current password is incorrect" });
      }

      // Hash new password
      const hashedNewPassword = await hashPassword(newPassword);

      // Update password in database
      const updateSql = `UPDATE ${table} SET password = ? WHERE id = ?`;
      
      db.query(updateSql, [hashedNewPassword, userId], (updateErr, updateResult) => {
        if (updateErr) {
          console.error("❌ Failed to update password:", updateErr);
          return res.status(500).json({ message: "Failed to update password" });
        }

        if (updateResult.affectedRows === 0) {
          return res.status(404).json({ message: "Failed to update password" });
        }

        console.log("✅ Password changed successfully for User ID:", userId);

        // Send email notification
        const mailOptions = {
          to: email,
          subject: "Password Changed Successfully - Campus Entry Guide",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">✅ Password Changed Successfully!</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${user.full_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  Your password has been changed successfully. If you did not make this change, please contact support immediately.
                </p>
                
                <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <p style="color: #2e7d32; margin: 0;"><strong>Account:</strong> ${email}</p>
                  <p style="color: #2e7d32; margin: 0;"><strong>Role:</strong> ${role}</p>
                  <p style="color: #2e7d32; margin: 0;"><strong>Changed on:</strong> ${new Date().toLocaleString()}</p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr, info) => {
          if (mailErr) {
            console.error("⚠️ Failed to send password change email:", mailErr);
          } else {
            console.log("✅ Password change email sent to:", email);
          }
        });

        res.status(200).json({
          message: "Password changed successfully",
        });
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// ================= GOOGLE LOGIN - CHECK EMAIL & SEND OTP =================
app.post("/google-check-email", async (req, res) => {
  const { email } = req.body;
  
  if (!email) {
    return res.status(400).json({ message: "Email is required" });
  }

  const tables = [
    { name: "student_registration", role: "Student" },
    { name: "teacher_registration", role: "Teacher" },
    { name: "admin_registration", role: "Admin" }
  ];

  let foundUser = null;
  let userRole = null;
  let tableName = null;

  // Check if user exists in any table
  for (const table of tables) {
    const sqlCheck = `SELECT * FROM ${table.name} WHERE email = ? LIMIT 1`;
    const results = await new Promise((resolve) =>
      db.query(sqlCheck, [email], (err, results) => {
        if (err) return resolve([]);
        resolve(results);
      })
    );

    if (results.length > 0) {
      foundUser = results[0];
      userRole = table.role;
      tableName = table.name;
      break;
    }
  }

  // If user not found in any table
  if (!foundUser) {
    return res.status(404).json({ 
      message: "Email not found. Please register first.",
      found: false
    });
  }

  // Generate OTP and send to email
  const otp = generateOtp();
  const expiry = Date.now() + 5 * 60 * 1000; // 5 minutes

  console.log(`✅ Generated OTP for ${email}: ${otp}`);

  // Update OTP in database
  const updateSql = `UPDATE ${tableName} SET otp=?, otp_expiry=? WHERE email=?`;
  db.query(updateSql, [otp, expiry, email], (dbErr) => {
    if (dbErr) {
      console.error("❌ Failed to save OTP:", dbErr);
      return res.status(500).json({ message: "Failed to generate OTP" });
    }

    // Send OTP email
    const mailOptions = {
      to: email,
      subject: "Google Sign-In Verification - Campus Entry Guide",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
          <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
            </div>
            
            <h2 style="color: #333; margin-bottom: 20px;">🔐 Google Sign-In Verification</h2>
            
            <p style="color: #666; font-size: 16px; line-height: 1.6;">
              Hello ${foundUser.full_name},
            </p>
            
            <p style="color: #666; font-size: 16px; line-height: 1.6;">
              You are attempting to sign in with Google. Please use the verification code below to complete your login:
            </p>
            
            <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 25px; text-align: center; border-radius: 8px; margin: 30px 0;">
              <div style="font-size: 42px; font-weight: bold; color: white; letter-spacing: 12px; font-family: 'Courier New', monospace;">
                ${otp}
              </div>
            </div>
            
            <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                <strong>Account Details:</strong><br>
                Email: ${email}<br>
                Role: ${userRole}
              </p>
            </div>
            
            <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #856404; margin: 0; font-size: 14px;">
                ⏰ This code will expire in <strong>5 minutes</strong>
              </p>
            </div>
            
            <p style="color: #999; font-size: 13px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              If you didn't request this code, please ignore this email or contact support if you have concerns.
            </p>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #999; font-size: 12px; margin: 0;">
                © 2025 Campus Entry Guide. All rights reserved.
              </p>
            </div>
          </div>
        </div>
      `,
    };

    mailTransporter.sendMail(mailOptions, (mailErr, info) => {
      if (mailErr) {
        console.error("❌ Email Error:", mailErr);
        return res.status(500).json({ message: "Failed to send OTP email" });
      }

      console.log("✅ OTP email sent:", info.response);
      res.json({ 
        message: "OTP sent to your email",
        found: true,
        role: userRole,
        fullName: foundUser.full_name
      });
    });
  });
});

// ================= GOOGLE LOGIN - VERIFY OTP =================
app.post("/google-verify-otp", async (req, res) => {
  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ message: "Email and OTP are required" });
  }

  const tables = [
    { name: "student_registration", role: "Student" },
    { name: "teacher_registration", role: "Teacher" },
    { name: "admin_registration", role: "Admin" }
  ];

  let foundUser = null;
  let userRole = null;
  let tableName = null;

  // Find user in tables
  for (const table of tables) {
    const sqlCheck = `SELECT * FROM ${table.name} WHERE email = ? LIMIT 1`;
    const results = await new Promise((resolve) =>
      db.query(sqlCheck, [email], (err, results) => {
        if (err) return resolve([]);
        resolve(results);
      })
    );

    if (results.length > 0) {
      foundUser = results[0];
      userRole = table.role;
      tableName = table.name;
      break;
    }
  }

  if (!foundUser) {
    return res.status(404).json({ message: "User not found" });
  }

  console.log("🔍 Stored OTP:", foundUser.otp, "| Provided OTP:", otp);
  console.log("🔍 OTP Expiry:", foundUser.otp_expiry, "| Current Time:", Date.now());

  // Verify OTP
  if (foundUser.otp !== otp) {
    return res.status(400).json({ message: "Invalid OTP" });
  }

  if (Date.now() > foundUser.otp_expiry) {
    return res.status(400).json({ message: "OTP has expired" });
  }

  // Generate default password
  const defaultPassword = Math.floor(100000 + Math.random() * 900000).toString();
  const hashedPassword = await hashPassword(defaultPassword);

  // Update password and clear OTP
  const updateSql = `UPDATE ${tableName} SET password=?, otp=NULL, otp_expiry=NULL WHERE email=?`;
  db.query(updateSql, [hashedPassword, email], (updateErr) => {
    if (updateErr) {
      console.error("❌ Failed to update password:", updateErr);
      return res.status(500).json({ message: "Failed to update password" });
    }

    // Send password email
    const passwordMailOptions = {
      to: email,
      subject: "Your New Login Password - Campus Entry Guide",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
          <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
            </div>
            
            <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
              <h2 style="color: white; margin: 0;">✅ Login Successful!</h2>
            </div>
            
            <h3 style="color: #333; margin-bottom: 15px;">Hi ${foundUser.full_name},</h3>
            
            <p style="color: #666; font-size: 16px; line-height: 1.6;">
              You have successfully logged in with Google. Your default password for future logins has been set.
            </p>
            
            <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
              <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Your Login Credentials:</h4>
              <p style="color: #1b5e20; margin: 5px 0;"><strong>Email:</strong> ${email}</p>
              <p style="color: #1b5e20; margin: 5px 0;"><strong>Role:</strong> ${userRole}</p>
              <p style="color: #1b5e20; margin: 5px 0;"><strong>Default Password:</strong> <span style="font-size: 24px; font-weight: bold; font-family: 'Courier New', monospace;">${defaultPassword}</span></p>
            </div>
            
            <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #856404; margin: 0; font-size: 14px;">
                <strong>⚠️ Security Note:</strong><br>
                Please save this password in a secure location. You can use this password for future logins or continue using Google Sign-In.
              </p>
            </div>
            
            <p style="color: #666; font-size: 14px; line-height: 1.6; margin-top: 30px;">
              <strong>Security Tips:</strong><br>
              • Keep your password confidential<br>
              • You can change this password anytime from your profile<br>
              • Use Google Sign-In for faster access<br>
            </p>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #999; font-size: 12px; margin: 0;">
                © 2025 Campus Entry Guide. All rights reserved.
              </p>
            </div>
          </div>
        </div>
      `,
    };

    mailTransporter.sendMail(passwordMailOptions, (mailErr, info) => {
      if (mailErr) {
        console.error("⚠️ Failed to send password email:", mailErr);
      } else {
        console.log("✅ Password email sent to:", email);
      }
    });

    console.log("✅ Google OTP verified successfully for:", email);

    res.json({
      message: "Login success",
      user: {
        id: foundUser.id,
        full_name: foundUser.full_name,
        email: foundUser.email,
        role: userRole,
        phone_number: foundUser.phone_number || null,
      },
    });
  });
});

// ================= EMAIL OTP ENDPOINTS (FORGET PASSWORD) =================
app.post("/send-email-otp", (req, res) => {
  console.log("📧 Email OTP Request:", req.body);
  
  const { email, role } = req.body;
  const table = getTableByRole(role);
  
  if (!email || !table) {
    console.log("❌ Invalid request - missing email or role");
    return res.status(400).json({ message: "Invalid request" });
  }

  db.query(
    `SELECT * FROM ${table} WHERE email=? LIMIT 1`,
    [email],
    (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error" });
      }

      if (results.length === 0) {
        console.log("❌ Email not found:", email);
        return res.status(404).json({ message: "Email not found in database" });
      }

      const otp = generateOtp();
      const expiry = Date.now() + 60 * 1000;

      console.log(`✅ Generated OTP for ${email}: ${otp}`);

      db.query(
        `UPDATE ${table} SET otp=?, otp_expiry=? WHERE email=?`,
        [otp, expiry, email],
        (dbErr) => {
          if (dbErr) {
            console.error("❌ Failed to save OTP:", dbErr);
            return res.status(500).json({ message: "Failed to generate OTP" });
          }

          const mailOptions = {
            to: email,
            subject: "OTP Verification - Campus Entry Guide",
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
                <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                  <div style="text-align: center; margin-bottom: 30px;">
                    <h1 style="color: #4CAF50; margin: 0;">Campus Entry Guide</h1>
                  </div>
                  
                  <h2 style="color: #333; margin-bottom: 20px;">Verification Code</h2>
                  
                  <p style="color: #666; font-size: 16px; line-height: 1.6;">
                    Hello! You have requested to reset your password. Please use the verification code below:
                  </p>
                  
                  <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 25px; text-align: center; border-radius: 8px; margin: 30px 0;">
                    <div style="font-size: 42px; font-weight: bold; color: white; letter-spacing: 12px; font-family: 'Courier New', monospace;">
                      ${otp}
                    </div>
                  </div>
                  
                  <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
                    <p style="color: #856404; margin: 0; font-size: 14px;">
                      ⏰ This code will expire in <strong>1 minute</strong>
                    </p>
                  </div>
                  
                  <p style="color: #999; font-size: 13px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                    If you didn't request this code, please ignore this email or contact support if you have concerns.
                  </p>
                  
                  <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                    <p style="color: #999; font-size: 12px; margin: 0;">
                      © 2025 Campus Entry Guide. All rights reserved.
                    </p>
                  </div>
                </div>
              </div>
            `,
          };

          mailTransporter.sendMail(mailOptions, (mailErr, info) => {
            if (mailErr) {
              console.error("❌ Email Error:", mailErr);
              return res.status(500).json({ message: "Failed to send OTP email" });
            }

            console.log("✅ Email sent:", info.response);
            res.json({ message: "OTP sent to email" });
          });
        }
      );
    }
  );
});

app.post("/verify-email-otp", (req, res) => {
  console.log("🔍 Verify Email OTP Request:", req.body);
  
  const { email, otp, role } = req.body;
  const table = getTableByRole(role);

  if (!email || !otp || !table) {
    console.log("❌ Invalid request - missing parameters");
    return res.status(400).json({ message: "Invalid request" });
  }

  db.query(
    `SELECT * FROM ${table} WHERE email=? LIMIT 1`,
    [email],
    (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error" });
      }

      if (results.length === 0) {
        console.log("❌ Email not found:", email);
        return res.status(404).json({ message: "Email not found" });
      }

      const user = results[0];

      console.log("🔍 Stored OTP:", user.otp, "| Provided OTP:", otp);
      console.log("🔍 OTP Expiry:", user.otp_expiry, "| Current Time:", Date.now());

      if (user.otp !== otp) {
        console.log("❌ Invalid OTP");
        return res.status(400).json({ message: "Invalid OTP" });
      }

      if (Date.now() > user.otp_expiry) {
        console.log("❌ OTP expired");
        return res.status(400).json({ message: "OTP has expired" });
      }

      db.query(
        `UPDATE ${table} SET otp=NULL, otp_expiry=NULL WHERE email=?`,
        [email],
        (clearErr) => {
          if (clearErr) {
            console.error("⚠️ Error clearing OTP:", clearErr);
          }
        }
      );

      console.log("✅ OTP verified successfully for:", email);

      res.json({
        message: "Login success",
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          role,
          phone_number: user.phone_number || null,
        },
      });
    }
  );
});


// ================= UPDATE ANNOUNCEMENTS TABLE =================
// Run this SQL to add the new columns:

// ================= UPDATED CREATE ANNOUNCEMENT =================
// ================= CREATE ANNOUNCEMENT =================
app.post("/create-announcement", (req, res) => {
  const { title, description, category, target_role, image_url, created_by } = req.body;

  if (!title || !description || !category || !created_by) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const sql = `
    INSERT INTO announcements 
    (title, description, category, target_role, image_url, created_by, created_at, updated_at, is_active)
    VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW(), 1)
  `;

  const values = [
    title,
    description,
    category,
    target_role || 'all',
    image_url || null,
    created_by
  ];

  db.query(sql, values, (err, result) => {
    if (err) {
      console.error("❌ Error creating announcement:", err);
      return res.status(500).json({ message: "Failed to create announcement", error: err });
    }

    console.log(`✅ Announcement created with ID: ${result.insertId} by admin ${created_by}`);
    res.status(201).json({
      message: "Announcement created successfully",
      announcementId: result.insertId,
    });
  });
});
// ================= GET ADMIN ANNOUNCEMENTS WITH PROFILE IMAGE =================
app.post("/get-admin-announcements", (req, res) => {
  const { created_by } = req.body;

  if (!created_by) {
    return res.status(400).json({ message: "Admin ID is required" });
  }

  const sql = `
    SELECT 
      a.*,
      a.created_by_name,
      ar.profile_image as admin_profile_image
    FROM announcements a
    LEFT JOIN admin_registration ar ON a.created_by = ar.id
    WHERE a.created_by = ?
    ORDER BY a.created_at DESC
  `;

  db.query(sql, [created_by], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch announcements", error: err });
    }

    console.log(`✅ Fetched ${results.length} announcements for admin with profile images`);

    res.status(200).json({
      message: "Announcements fetched successfully",
      announcements: results,
    });
  });
});

// ================= GET ALL ANNOUNCEMENTS (ALL ADMINS) =================
app.post("/get-all-announcements", (req, res) => {
  const sql = `
    SELECT 
      a.id,
      a.title,
      a.description,
      a.category,
      a.target_role,
      a.image_url,
      a.created_at,
      a.updated_at,
      a.is_active,
      a.created_by,
      ar.full_name as created_by_name,
      ar.profile_image as admin_profile_image
    FROM announcements a
    LEFT JOIN admin_registration ar ON a.created_by = ar.id
    ORDER BY a.created_at DESC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch announcements", error: err });
    }

    console.log(`✅ Fetched ${results.length} announcements from all admins`);
    
    // Log which admins have posts
    const adminCounts = {};
    results.forEach(r => {
      adminCounts[r.created_by_name] = (adminCounts[r.created_by_name] || 0) + 1;
    });
    console.log("📊 Announcements per admin:", adminCounts);

    res.status(200).json({
      message: "Announcements fetched successfully",
      announcements: results,
    });
  });
});

// ================= GET USER NOTIFICATIONS WITH READ STATUS (FIXED) =================
app.post("/get-user-notifications", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  console.log(`📬 Fetching notifications for User ID: ${userId}, Role: ${userRole}`);

  // ✅ FIX: Normalize role to handle singular/plural
  const normalizedRole = userRole.toLowerCase();
  const targetRole = normalizedRole === 'teacher' ? 'teachers' : 
                     normalizedRole === 'student' ? 'students' : 
                     normalizedRole;

  let sql;
  let queryParams;

  if (normalizedRole === 'admin') {
    // Admin sees ALL announcements
    sql = `
      SELECT 
        a.id,
        a.title,
        a.description,
        a.category,
        a.target_role,
        a.image_url,
        a.created_at,
        a.is_active,
        a.created_by,
        ar.full_name as created_by_name,
        ar.profile_image as admin_profile_image,
        COALESCE(anr.is_read, 0) as is_read,
        anr.read_at
      FROM announcements a
      LEFT JOIN admin_registration ar ON a.created_by = ar.id
      LEFT JOIN announcement_reads anr ON a.id = anr.announcement_id 
        AND anr.user_id = ? 
        AND anr.user_role = ?
      WHERE a.is_active = 1
      ORDER BY 
        COALESCE(anr.is_read, 0) ASC,
        a.created_at DESC
    `;
    queryParams = [userId, userRole];
  } else {
    // Teachers and Students see only their role + "all"
    // ✅ FIX: Use normalized plural form for matching
    sql = `
      SELECT 
        a.id,
        a.title,
        a.description,
        a.category,
        a.target_role,
        a.image_url,
        a.created_at,
        a.is_active,
        a.created_by,
        ar.full_name as created_by_name,
        ar.profile_image as admin_profile_image,
        COALESCE(anr.is_read, 0) as is_read,
        anr.read_at
      FROM announcements a
      LEFT JOIN admin_registration ar ON a.created_by = ar.id
      LEFT JOIN announcement_reads anr ON a.id = anr.announcement_id 
        AND anr.user_id = ? 
        AND anr.user_role = ?
      WHERE a.is_active = 1 
        AND (
          LOWER(a.target_role) = 'all' 
          OR LOWER(a.target_role) = ?
        )
      ORDER BY 
        COALESCE(anr.is_read, 0) ASC,
        a.created_at DESC
    `;
    queryParams = [userId, userRole, targetRole];
  }

  db.query(sql, queryParams, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch notifications", error: err });
    }

    const unreadCount = results.filter(n => n.is_read === 0).length;
    
    console.log(`✅ Fetched ${results.length} notifications (${unreadCount} unread) for ${userRole} user ${userId}`);
    console.log(`   Target role used: ${targetRole}`);
    console.log(`   Categories breakdown:`, results.reduce((acc, r) => {
      acc[r.category] = (acc[r.category] || 0) + 1;
      return acc;
    }, {}));

    res.status(200).json({
      message: "Notifications fetched successfully",
      notifications: results,
      unreadCount: unreadCount,
    });
  });
});
// ================= UPDATE ANNOUNCEMENT =================
app.post("/update-announcement", (req, res) => {
  const { id, title, description, category, target_role, image_url, is_active } = req.body;

  if (!id || !title || !description || !category) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  const sql = `
    UPDATE announcements
    SET title = ?, description = ?, category = ?, target_role = ?, image_url = ?, is_active = ?, updated_at = NOW()
    WHERE id = ?
  `;

  db.query(
    sql,
    [title, description, category, target_role || 'all', image_url || null, is_active !== undefined ? is_active : 1, id],
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to update announcement", error: err });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({ message: "Announcement not found" });
      }

      console.log("✅ Announcement updated:", id);

      res.status(200).json({
        message: "Announcement updated successfully",
      });
    }
  );
});

// ================= DELETE ANNOUNCEMENT =================
app.post("/delete-announcement", (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Announcement ID is required" });
  }

  const sql = `DELETE FROM announcements WHERE id = ?`;

  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to delete announcement", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Announcement not found" });
    }

    console.log("✅ Announcement deleted:", id);

    res.status(200).json({
      message: "Announcement deleted successfully",
    });
  });
});

// ================= MARK AS READ =================
app.post("/mark-notification-read", (req, res) => {
  const { announcementId, userId, userRole } = req.body;

  if (!announcementId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  console.log(`📖 Marking notification ${announcementId} as read for user ${userId} (${userRole})`);

  const sql = `
    INSERT INTO announcement_reads (announcement_id, user_id, user_role, is_read, read_at)
    VALUES (?, ?, ?, 1, NOW())
    ON DUPLICATE KEY UPDATE is_read = 1, read_at = NOW()
  `;

  db.query(sql, [announcementId, userId, userRole], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to mark as read", error: err });
    }

    console.log("✅ Notification marked as read:", announcementId);

    res.status(200).json({
      message: "Notification marked as read",
    });
  });
});

// ================= GET UNREAD COUNT =================
app.post("/get-unread-count", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const sql = `
    SELECT COUNT(*) as unreadCount
    FROM announcements a
    LEFT JOIN announcement_reads ar ON a.id = ar.announcement_id AND ar.user_id = ? AND ar.user_role = ?
    WHERE a.is_active = 1 AND (ar.is_read = 0 OR ar.is_read IS NULL)
  `;

  db.query(sql, [userId, userRole], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch unread count", error: err });
    }

    console.log(`✅ Unread count for user ${userId}:`, results[0].unreadCount);

    res.status(200).json({
      message: "Unread count fetched successfully",
      unreadCount: results[0].unreadCount,
    });
  });
});


// ================= FILTER CONFIGURATION ENDPOINTS =================
app.get("/get-filter-options", (req, res) => {
  const sql = `SELECT filter_type, filter_value FROM filter_configurations WHERE is_active = 1`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    const filters = {
      degrees: [],
      sections: [],
      semesters: [],
      departments: [],
      subjects: [],
      shifts: []
    };

    results.forEach(row => {
      if (row.filter_type === 'degree') filters.degrees.push(row.filter_value);
      if (row.filter_type === 'section') filters.sections.push(row.filter_value);
      if (row.filter_type === 'semester') filters.semesters.push(row.filter_value);
      if (row.filter_type === 'department') filters.departments.push(row.filter_value);
      if (row.filter_type === 'subject') filters.subjects.push(row.filter_value);
      if (row.filter_type === 'shift') filters.shifts.push(row.filter_value);
    });

    res.status(200).json(filters);
  });
});

app.post("/add-filter-option", (req, res) => {
  const { filter_type, filter_value } = req.body;

  if (!filter_type || !filter_value) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const sql = `INSERT INTO filter_configurations (filter_type, filter_value) VALUES (?, ?)`;
  
  db.query(sql, [filter_type, filter_value], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(201).json({ message: "Filter option added successfully" });
  });
});

app.post("/delete-filter-option", (req, res) => {
  const { filter_type, filter_value } = req.body;

  if (!filter_type || !filter_value) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const sql = `DELETE FROM filter_configurations WHERE filter_type = ? AND filter_value = ?`;
  
  db.query(sql, [filter_type, filter_value], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(200).json({ message: "Filter option deleted successfully" });
  });
});

// ================= STUDENT MANAGEMENT ENDPOINTS =================
app.get("/get-all-students", (req, res) => {
  const sql = `SELECT id, full_name, email, arid_no, degree, semester_no, section, phone_number, profile_image FROM student_registration ORDER BY full_name ASC`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(200).json({ students: results });
  });
});

app.post("/add-student", async (req, res) => {
  const { full_name, email, arid_no, degree, semester_no, section, phone_number, password } = req.body;

  if (!full_name || !email || !arid_no || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  try {
    const exists = await checkEmailExists(email);
    if (exists) {
      return res.status(400).json({ message: "Email already exists" });
    }

    const hashedPassword = await hashPassword(password);

    const sql = `INSERT INTO student_registration (full_name, email, arid_no, degree, semester_no, section, phone_number, password) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
    
    db.query(sql, [full_name, email, arid_no, degree, semester_no, section, phone_number, hashedPassword], (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      res.status(201).json({ message: "Student added successfully", id: result.insertId });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

app.post("/update-student", (req, res) => {
  const { id, full_name, arid_no, degree, semester_no, section, phone_number } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Student ID is required" });
  }

  const sql = `UPDATE student_registration SET full_name = ?, arid_no = ?, degree = ?, semester_no = ?, section = ?, phone_number = ? WHERE id = ?`;
  
  db.query(sql, [full_name, arid_no, degree, semester_no, section, phone_number, id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Student not found" });
    }

    res.status(200).json({ message: "Student updated successfully" });
  });
});

app.post("/delete-student", (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Student ID is required" });
  }

  const sql = `DELETE FROM student_registration WHERE id = ?`;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Student not found" });
    }

    res.status(200).json({ message: "Student deleted successfully" });
  });
});

// ================= TEACHER MANAGEMENT ENDPOINTS =================
app.get("/get-all-teachers", (req, res) => {
  const sql = `SELECT id, full_name, email, department, subject_name, shift, phone_number, profile_image FROM teacher_registration ORDER BY full_name ASC`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    res.status(200).json({ teachers: results });
  });
});

app.post("/add-teacher", async (req, res) => {
  const { full_name, email, department, subject_name, shift, phone_number, password } = req.body;

  if (!full_name || !email || !password) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  try {
    const exists = await checkEmailExists(email);
    if (exists) {
      return res.status(400).json({ message: "Email already exists" });
    }

    const hashedPassword = await hashPassword(password);

    const sql = `INSERT INTO teacher_registration (full_name, email, department, subject_name, shift, phone_number, password) VALUES (?, ?, ?, ?, ?, ?, ?)`;
    
    db.query(sql, [full_name, email, department, subject_name, shift, phone_number, hashedPassword], (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      res.status(201).json({ message: "Teacher added successfully", id: result.insertId });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error });
  }
});

app.post("/update-teacher", (req, res) => {
  const { id, full_name, department, subject_name, shift, phone_number } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  const sql = `UPDATE teacher_registration SET full_name = ?, department = ?, subject_name = ?, shift = ?, phone_number = ? WHERE id = ?`;
  
  db.query(sql, [full_name, department, subject_name, shift, phone_number, id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Teacher not found" });
    }

    res.status(200).json({ message: "Teacher updated successfully" });
  });
});

app.post("/delete-teacher", (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  const sql = `DELETE FROM teacher_registration WHERE id = ?`;
  
  db.query(sql, [id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Teacher not found" });
    }

    res.status(200).json({ message: "Teacher deleted successfully" });
  });
});



// ================= LOST & FOUND ENDPOINTS =================

// 📍 CATEGORIES & LOCATIONS CONSTANTS
const CATEGORIES = [
  "Electronics (Laptop, Phone, Charger)",
  "Keys & Cards (Keys, ID, Credit Card)",
  "Personal Items (Wallet, Bag, Watch)",
  "Documents (Books, Notebooks, Papers)",
  "Clothing (Jacket, Shoes, Scarf)",
  "Other"
];

const LOCATIONS = [
  "Library - 1st Floor",
  "Library - 2nd Floor",
  "Library - 3rd Floor",
  "Cafeteria - Main",
  "Cafeteria - Mini",
  "Parking Lot A",
  "Parking Lot B",
  "Classroom Building",
  "Lab Building",
  "Sports Complex",
  "Other"
];

// 📍 GET CATEGORIES & LOCATIONS
app.get("/get-lost-found-options", (req, res) => {
  res.status(200).json({
    categories: CATEGORIES,
    locations: LOCATIONS
  });
});

// 📍 REPORT LOST/FOUND ITEM
app.post("/report-lost-found-item", (req, res) => {
  const {
    item_name,
    description,
    image1,
    image2,
    type,
    category,
    location,
    reported_by_id,
    reported_by_name,
    reported_by_email,
    reported_by_phone,
    reported_by_role
  } = req.body;

  if (!item_name || !description || !type || !category || !location || !reported_by_id || !reported_by_name || !reported_by_email || !reported_by_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  if (type !== 'lost' && type !== 'found') {
    return res.status(400).json({ message: "Type must be 'lost' or 'found'" });
  }

  if (reported_by_role !== 'Student' && reported_by_role !== 'Teacher') {
    return res.status(400).json({ message: "Only Students and Teachers can report items" });
  }

  const sql = `
    INSERT INTO lost_found_items
    (item_name, description, image1, image2, type, category, location,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone, reported_by_role)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  db.query(
    sql,
    [item_name, description, image1 || null, image2 || null, type, category, location,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone || null, reported_by_role],
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to report item", error: err });
      }

      console.log(`✅ ${type.toUpperCase()} item reported by ${reported_by_name} (ID: ${result.insertId})`);

      // Send confirmation email
      const mailOptions = {
        to: reported_by_email,
        subject: `${type === 'lost' ? 'Lost' : 'Found'} Item Reported - Campus Entry Guide`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">✅ Item Reported Successfully!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${reported_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Your ${type} item has been successfully reported in our Lost & Found system.
              </p>
              
              <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Report Details:</h4>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Type:</strong> ${type === 'lost' ? 'Lost Item' : 'Found Item'}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Category:</strong> ${category}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Location:</strong> ${location}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Reported:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                  <strong>📢 What happens next:</strong><br>
                  • Your item will appear in the Lost & Found list<br>
                  • Others can search and claim it if it belongs to them<br>
                  • You'll be notified when someone claims it<br>
                  • Items are kept for 30 days, then archived
                </p>
              </div>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      mailTransporter.sendMail(mailOptions, (mailErr, info) => {
        if (mailErr) {
          console.error("⚠️ Failed to send confirmation email:", mailErr);
        } else {
          console.log("✅ Confirmation email sent to:", reported_by_email);
        }
      });

      res.status(201).json({
        message: "Item reported successfully",
        itemId: result.insertId,
      });
    }
  );
});

// 📍 GET LOST/FOUND ITEMS (WITH SEARCH & FILTERS)
app.post("/get-lost-found-items", (req, res) => {
  const { userId, userRole, searchQuery, type, status, category, location } = req.body;

  let sql = `SELECT * FROM lost_found_items WHERE is_active = 1`;
  let params = [];

  // Search query (item_name OR description)
  if (searchQuery && searchQuery.trim() !== '') {
    sql += ` AND (item_name LIKE ? OR description LIKE ?)`;
    params.push(`%${searchQuery}%`, `%${searchQuery}%`);
  }

  // Filter by type (lost/found)
  if (type && type !== 'all') {
    sql += ` AND type = ?`;
    params.push(type);
  }

  // Filter by status
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  // Filter by category
  if (category && category !== 'all') {
    sql += ` AND category = ?`;
    params.push(category);
  }

  // Filter by location
  if (location && location !== 'all') {
    sql += ` AND location = ?`;
    params.push(location);
  }

  sql += ` ORDER BY reported_at DESC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch items", error: err });
    }

    console.log(`✅ Fetched ${results.length} lost/found items`);

    // Add flags for current user's permissions
    const enhancedResults = results.map(item => {
      const isOwnReport = item.reported_by_id === userId && item.reported_by_role === userRole;
      const hasClaimed = item.claimed_by_id === userId && item.claimed_by_role === userRole;
      const canEdit = isOwnReport && item.status === 'pending';
      const canClaim = !isOwnReport && item.status === 'pending';
      const canVerify = hasClaimed && item.status === 'pending';

      return {
        ...item,
        isOwnReport,
        hasClaimed,
        canEdit,
        canClaim,
        canVerify
      };
    });

    res.status(200).json({
      message: "Items fetched successfully",
      items: enhancedResults,
    });
  });
});

// 📍 CLAIM ITEM
app.post("/claim-item", (req, res) => {
  const {
    itemId,
    claimed_by_id,
    claimed_by_name,
    claimed_by_email,
    claimed_by_phone,
    claimed_by_role
  } = req.body;

  if (!itemId || !claimed_by_id || !claimed_by_name || !claimed_by_email || !claimed_by_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // First, get the item details
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Check if already claimed
    if (item.status === 'returned') {
      return res.status(400).json({ message: "This item has already been returned" });
    }

    // Check if user is claiming their own report
    if (item.reported_by_id === claimed_by_id && item.reported_by_role === claimed_by_role) {
      return res.status(400).json({ message: "You cannot claim your own report" });
    }

    // Update with claimer info
    const updateSql = `
      UPDATE lost_found_items
      SET claimed_by_id = ?, claimed_by_name = ?, claimed_by_email = ?, 
          claimed_by_phone = ?, claimed_by_role = ?, claimed_at = NOW()
      WHERE id = ?
    `;

    db.query(
      updateSql,
      [claimed_by_id, claimed_by_name, claimed_by_email, claimed_by_phone || null, claimed_by_role, itemId],
      (updateErr, updateResult) => {
        if (updateErr) {
          console.error("❌ Failed to claim item:", updateErr);
          return res.status(500).json({ message: "Failed to claim item", error: updateErr });
        }

        console.log(`✅ Item ${itemId} claimed by ${claimed_by_name}`);

        // Send email to reporter with claimer's contact
        const mailOptions = {
          to: item.reported_by_email,
          subject: `Someone Claimed Your ${item.type === 'lost' ? 'Lost' : 'Found'} Item - Campus Entry Guide`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">🔔 Item Claimed!</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${item.reported_by_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  Good news! Someone has claimed the ${item.type} item you reported.
                </p>
                
                <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Item Details:</h4>
                  <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item.item_name}</p>
                  <p style="color: #1b5e20; margin: 5px 0;"><strong>Category:</strong> ${item.category}</p>
                  <p style="color: #1b5e20; margin: 5px 0;"><strong>Location:</strong> ${item.location}</p>
                </div>
                
                <div style="background-color: #fff3e0; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #e65100; margin: 0 0 10px 0;">Claimer Contact Information:</h4>
                  <p style="color: #bf360c; margin: 5px 0;"><strong>Name:</strong> ${claimed_by_name}</p>
                  <p style="color: #bf360c; margin: 5px 0;"><strong>Email:</strong> ${claimed_by_email}</p>
                  <p style="color: #bf360c; margin: 5px 0;"><strong>Role:</strong> ${claimed_by_role}</p>
                </div>
                
                <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                  <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                    <strong>📢 Next Steps:</strong><br>
                    • Please contact the claimer via email<br>
                    • Arrange a safe meeting location on campus<br>
                    • Verify the item belongs to them<br>
                    • Once confirmed, they will verify in the app
                  </p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr, info) => {
          if (mailErr) {
            console.error("⚠️ Failed to send claim notification email:", mailErr);
          } else {
            console.log("✅ Claim notification sent to:", item.reported_by_email);
          }
        });

        res.status(200).json({
          message: "Item claimed successfully",
          reporterEmail: item.reported_by_email,
          reporterName: item.reported_by_name
        });
      }
    );
  });
});

// 📍 VERIFY ITEM (Mark as Returned)
app.post("/verify-item", (req, res) => {
  const { itemId, userId, userRole } = req.body;

  if (!itemId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get item details first
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Verify the user is the claimer
    if (item.claimed_by_id !== userId || item.claimed_by_role !== userRole) {
      return res.status(403).json({ message: "Only the claimer can verify this item" });
    }

    // Update status to returned
    const updateSql = `
      UPDATE lost_found_items
      SET status = 'returned', verified_at = NOW()
      WHERE id = ?
    `;

    db.query(updateSql, [itemId], (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to verify item:", updateErr);
        return res.status(500).json({ message: "Failed to verify item", error: updateErr });
      }

      console.log(`✅ Item ${itemId} verified as returned by ${item.claimed_by_name}`);

      // Send confirmation emails to both parties
      const reporterMailOptions = {
        to: item.reported_by_email,
        subject: `Item Returned Successfully - Campus Entry Guide`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">🎉 Item Successfully Returned!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${item.reported_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Great news! The ${item.type} item has been successfully returned to its owner.
              </p>
              
              <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Item Details:</h4>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item.item_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Returned to:</strong> ${item.claimed_by_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Verified on:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Thank you for using the Lost & Found system and helping reunite items with their owners!
              </p>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      const claimerMailOptions = {
        to: item.claimed_by_email,
        subject: `Item Verification Confirmed - Campus Entry Guide`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #11998e; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">✅ Verification Confirmed!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${item.claimed_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                You have successfully verified that you received your item. The report has been marked as returned.
              </p>
              
              <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Item Details:</h4>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Item:</strong> ${item.item_name}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Category:</strong> ${item.category}</p>
                <p style="color: #1b5e20; margin: 5px 0;"><strong>Verified on:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                We're glad you got your item back safely!
              </p>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      // Send both emails
      mailTransporter.sendMail(reporterMailOptions, (err1) => {
        if (err1) console.error("⚠️ Failed to send reporter email:", err1);
        else console.log("✅ Verification email sent to reporter");
      });

      mailTransporter.sendMail(claimerMailOptions, (err2) => {
        if (err2) console.error("⚠️ Failed to send claimer email:", err2);
        else console.log("✅ Verification email sent to claimer");
      });

      res.status(200).json({
        message: "Item verified as returned successfully",
      });
    });
  });
});

// 📍 UPDATE LOST/FOUND ITEM (Only before claiming)
app.post("/update-lost-found-item", (req, res) => {
  const {
    itemId,
    userId,
    userRole,
    item_name,
    description,
    image1,
    image2,
    category,
    location
  } = req.body;

  if (!itemId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Check ownership and status
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Check if user owns this report
    if (item.reported_by_id !== userId || item.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only edit your own reports" });
    }

    // Check if item has been claimed
    if (item.status === 'returned' || item.claimed_by_id !== null) {
      return res.status(400).json({ message: "Cannot edit item after it has been claimed" });
    }

    // Build update query
    let updateFields = [];
    let updateValues = [];

    if (item_name) {
      updateFields.push("item_name = ?");
      updateValues.push(item_name);
    }
    if (description) {
      updateFields.push("description = ?");
      updateValues.push(description);
    }
    if (image1 !== undefined) {
      updateFields.push("image1 = ?");
      updateValues.push(image1);
    }
    if (image2 !== undefined) {
      updateFields.push("image2 = ?");
      updateValues.push(image2);
    }
    if (category) {
      updateFields.push("category = ?");
      updateValues.push(category);
    }
    if (location) {
      updateFields.push("location = ?");
      updateValues.push(location);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    updateValues.push(itemId);
    const updateSql = `UPDATE lost_found_items SET ${updateFields.join(", ")} WHERE id = ?`;

    db.query(updateSql, updateValues, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update item:", updateErr);
        return res.status(500).json({ message: "Failed to update item", error: updateErr });
      }

      console.log(`✅ Item ${itemId} updated by ${userRole} ${userId}`);

      res.status(200).json({
        message: "Item updated successfully",
      });
    });
  });
});

// 📍 DELETE LOST/FOUND ITEM (Only before claiming OR by admin)
app.post("/delete-lost-found-item", (req, res) => {
  const { itemId, userId, userRole } = req.body;

  if (!itemId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get item details
  db.query(`SELECT * FROM lost_found_items WHERE id = ?`, [itemId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Item not found" });
    }

    const item = results[0];

    // Admin can always delete
    if (userRole === 'Admin') {
      db.query(`DELETE FROM lost_found_items WHERE id = ?`, [itemId], (delErr) => {
        if (delErr) {
          console.error("❌ Failed to delete item:", delErr);
          return res.status(500).json({ message: "Failed to delete item", error: delErr });
        }

        console.log(`✅ Admin deleted item ${itemId}`);
        res.status(200).json({ message: "Item deleted successfully by admin" });
      });
      return;
    }

    // Student/Teacher can only delete their own unclaimed items
    if (item.reported_by_id !== userId || item.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only delete your own reports" });
    }

    if (item.status === 'returned' || item.claimed_by_id !== null) {
      return res.status(400).json({ message: "Cannot delete item after it has been claimed" });
    }

    db.query(`DELETE FROM lost_found_items WHERE id = ?`, [itemId], (delErr) => {
      if (delErr) {
        console.error("❌ Failed to delete item:", delErr);
        return res.status(500).json({ message: "Failed to delete item", error: delErr });
      }

      console.log(`✅ Item ${itemId} deleted by ${userRole} ${userId}`);
      res.status(200).json({ message: "Item deleted successfully" });
    });
  });
});

// 📍 GET ALL LOST/FOUND REPORTS FOR ADMIN
app.get("/get-admin-lost-found-reports", (req, res) => {
  const sql = `
    SELECT * FROM lost_found_items 
    WHERE is_active = 1
    ORDER BY 
      CASE 
        WHEN status = 'pending' THEN 1
        WHEN status = 'returned' THEN 2
      END,
      reported_at DESC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch admin reports", error: err });
    }

    console.log(`✅ Admin fetched ${results.length} lost/found reports`);

    res.status(200).json({
      message: "Reports fetched successfully",
      reports: results,
    });
  });
});

// 📍 AUTO-ARCHIVE CRON JOB (Archive items after 30 days, delete after 50 days)
setInterval(() => {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const fiftyDaysAgo = new Date(Date.now() - 50 * 24 * 60 * 60 * 1000);

  // Archive items older than 30 days
  db.query(
    `UPDATE lost_found_items SET is_active = 0 WHERE reported_at < ? AND is_active = 1`,
    [thirtyDaysAgo],
    (err, result) => {
      if (err) {
        console.error("❌ Auto-archive error:", err);
      } else if (result.affectedRows > 0) {
        console.log(`📦 Auto-archived ${result.affectedRows} items older than 30 days`);
      }
    }
  );

  // Delete items older than 50 days
  db.query(
    `DELETE FROM lost_found_items WHERE reported_at < ?`,
    [fiftyDaysAgo],
    (err, result) => {
      if (err) {
        console.error("❌ Auto-delete error:", err);
      } else if (result.affectedRows > 0) {
        console.log(`🗑️ Auto-deleted ${result.affectedRows} items older than 50 days`);
      }
    }
  );
}, 24 * 60 * 60 * 1000); // Run every 24 hours

console.log("✅ Lost & Found auto-archive system initialized (30 days archive, 50 days delete)")



// ================= COMPLAINT SYSTEM ENDPOINTS =================

// 📍 COMPLAINT CATEGORIES
const COMPLAINT_CATEGORIES = [
  "Room/Facility Issues (AC, Lights, Furniture)",
  "Cleanliness Issues",
  "Safety Concerns",
  "Equipment/Lab Issues",
  "Other"
];

// 📍 GET COMPLAINT OPTIONS
app.get("/get-complaint-options", (req, res) => {
  res.status(200).json({
    categories: COMPLAINT_CATEGORIES,
    locations: LOCATIONS, // Using same locations as Lost & Found
    priorities: ['Low', 'Medium', 'High']
  });
});

// 📍 CREATE COMPLAINT
// 📍 CREATE COMPLAINT
app.post("/create-complaint", (req, res) => {
  const {
    title,
    description,
    category,
    location,
    priority,
    image,
    reported_by_id,
    reported_by_name,
    reported_by_email,
    reported_by_phone,
    reported_by_role,
    reported_by_degree,
    reported_by_section,
    reported_by_department  // ✅ ADD THIS
  } = req.body;

  if (!title || !description || !category || !location || !reported_by_id || !reported_by_name || !reported_by_email || !reported_by_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  if (reported_by_role !== 'Student' && reported_by_role !== 'Teacher') {
    return res.status(400).json({ message: "Only Students and Teachers can file complaints" });
  }

  const sql = `
    INSERT INTO complaints
    (title, description, category, location, priority, image,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone, reported_by_role,
     reported_by_degree, reported_by_section, reported_by_department)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  db.query(
    sql,
    [title, description, category, location, priority || 'Medium', image || null,
     reported_by_id, reported_by_name, reported_by_email, reported_by_phone || null, reported_by_role,
     reported_by_degree || null, reported_by_section || null, reported_by_department || null],  // ✅ ADD THIS
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to create complaint", error: err });
      }

      console.log(`✅ Complaint created by ${reported_by_name} (ID: ${result.insertId})`);

      // Send confirmation email to reporter
      const mailOptions = {
        to: reported_by_email,
        subject: "Complaint Submitted Successfully - Campus Entry Guide",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #FF512F; margin: 0;">Campus Entry Guide</h1>
              </div>
              
              <div style="background: linear-gradient(135deg, #FF512F 0%, #DD2476 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                <h2 style="color: white; margin: 0;">✅ Complaint Submitted!</h2>
              </div>
              
              <h3 style="color: #333; margin-bottom: 15px;">Hi ${reported_by_name},</h3>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6;">
                Your complaint has been successfully submitted. Our admin team will review it shortly.
              </p>
              
              <div style="background-color: #fff3e0; padding: 20px; border-radius: 8px; margin: 25px 0;">
                <h4 style="color: #e65100; margin: 0 0 10px 0;">Complaint Details:</h4>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Title:</strong> ${title}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Category:</strong> ${category}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Location:</strong> ${location}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Priority:</strong> ${priority || 'Medium'}</p>
                <p style="color: #bf360c; margin: 5px 0;"><strong>Status:</strong> Pending</p>
              </div>
              
              <div style="background-color: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                <p style="color: #0d47a1; margin: 0; font-size: 14px;">
                  <strong>📢 What happens next:</strong><br>
                  • Admin will review your complaint<br>
                  • You'll be notified when work begins<br>
                  • You'll be notified when issue is resolved<br>
                  • You can track status in the app
                </p>
              </div>
              
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #999; font-size: 12px; margin: 0;">
                  © 2025 Campus Entry Guide. All rights reserved.
                </p>
              </div>
            </div>
          </div>
        `,
      };

      mailTransporter.sendMail(mailOptions, (mailErr, info) => {
        if (mailErr) {
          console.error("⚠️ Failed to send confirmation email:", mailErr);
        } else {
          console.log("✅ Confirmation email sent to:", reported_by_email);
        }
      });

      // Notify admin about new complaint
      db.query(`SELECT email, full_name FROM admin_registration WHERE id = 1 LIMIT 1`, (adminErr, adminResults) => {
        if (!adminErr && adminResults.length > 0) {
          const admin = adminResults[0];
          const adminMailOptions = {
            to: admin.email,
            subject: "New Complaint Filed - Campus Entry Guide",
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
                <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                  <h2 style="color: #FF512F;">🔔 New Complaint Filed</h2>
                  <p><strong>Title:</strong> ${title}</p>
                  <p><strong>Category:</strong> ${category}</p>
                  <p><strong>Location:</strong> ${location}</p>
                  <p><strong>Priority:</strong> ${priority || 'Medium'}</p>
                  <p><strong>Reported by:</strong> ${reported_by_name} (${reported_by_role})</p>
                  <p>Please check the admin panel for details.</p>
                </div>
              </div>
            `,
          };
          mailTransporter.sendMail(adminMailOptions);
        }
      });

      res.status(201).json({
        message: "Complaint created successfully",
        complaintId: result.insertId,
      });
    }
  );
});

// 📍 GET USER COMPLAINTS (For Students/Teachers)
app.post("/get-user-complaints", (req, res) => {
  const { userId, userRole, searchQuery, status, category, priority } = req.body;

   let sql = `
    SELECT 
      *,
      reported_by_degree,
      reported_by_section
    FROM complaints 
    WHERE is_active = 1
  `;
  let params = [];

  // Search query
  if (searchQuery && searchQuery.trim() !== '') {
    sql += ` AND (title LIKE ? OR description LIKE ?)`;
    params.push(`%${searchQuery}%`, `%${searchQuery}%`);
  }

  // Filter by status
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  // Filter by category
  if (category && category !== 'all') {
    sql += ` AND category = ?`;
    params.push(category);
  }

  // Filter by priority
  if (priority && priority !== 'all') {
    sql += ` AND priority = ?`;
    params.push(priority);
  }

  sql += ` ORDER BY created_at DESC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch complaints", error: err });
    }

    // ✅ FIX: Always show full info, add flags for permissions
    const sanitizedResults = results.map(complaint => {
      const isOwnComplaint = complaint.reported_by_id === userId && complaint.reported_by_role === userRole;
      
      return {
        ...complaint,
        isOwnComplaint: isOwnComplaint,
        canEdit: isOwnComplaint && complaint.status === 'pending',
        canDelete: isOwnComplaint && !complaint.verified_by_reporter
      };
    });

    res.status(200).json({
      message: "Complaints fetched successfully",
      complaints: sanitizedResults,
    });
  });
});

// ================= REPLACE THE EXISTING /get-admin-complaints ENDPOINT WITH THIS =================

app.post("/get-admin-complaints", (req, res) => {
  const { reporterRole, status, category, priority, location, searchQuery } = req.body;

  let sql = `
    SELECT 
      *,
      reported_by_degree,
      reported_by_section
    FROM complaints 
    WHERE is_active = 1
  `;
  let params = [];

  // Filter by reporter role (Student, Teacher, or null for all)
  if (reporterRole && reporterRole !== 'all') {
    sql += ` AND reported_by_role = ?`;
    params.push(reporterRole);
  }

  // Filter by status
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  // Filter by category
  if (category && category !== 'all') {
    sql += ` AND category = ?`;
    params.push(category);
  }

  // Filter by priority
  if (priority && priority !== 'all') {
    sql += ` AND priority = ?`;
    params.push(priority);
  }

  // Filter by location
  if (location && location !== 'all') {
    sql += ` AND location = ?`;
    params.push(location);
  }

  // Search query across title, description, name, email
  if (searchQuery && searchQuery.trim() !== '') {
    sql += ` AND (title LIKE ? OR description LIKE ? OR reported_by_name LIKE ? OR reported_by_email LIKE ?)`;
    params.push(`%${searchQuery}%`, `%${searchQuery}%`, `%${searchQuery}%`, `%${searchQuery}%`);
  }

  sql += ` ORDER BY 
    CASE 
      WHEN status = 'pending' THEN 1
      WHEN status = 'in_progress' THEN 2
      WHEN status = 'resolved' THEN 3
    END,
    created_at DESC`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch complaints", error: err });
    }

    console.log(`✅ Admin fetched ${results.length} complaints`);

    res.status(200).json({
      message: "Complaints fetched successfully",
      complaints: results,
    });
  });
});

// 📍 UPDATE COMPLAINT STATUS (Admin)
app.post("/update-complaint-status", (req, res) => {
  const { complaintId, status, adminId, adminName, adminResponse } = req.body;

  if (!complaintId || !status || !adminId) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details first
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    let updateSql = `UPDATE complaints SET status = ?, admin_id = ?, admin_name = ?`;
    let updateParams = [status, adminId, adminName];

    if (adminResponse) {
      updateSql += `, admin_response = ?`;
      updateParams.push(adminResponse);
    }

    if (status === 'in_progress' && !complaint.admin_started_at) {
      updateSql += `, admin_started_at = NOW()`;
    }

    if (status === 'resolved' && !complaint.resolved_at) {
      updateSql += `, resolved_at = NOW()`;
    }

    updateSql += ` WHERE id = ?`;
    updateParams.push(complaintId);

    db.query(updateSql, updateParams, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update status:", updateErr);
        return res.status(500).json({ message: "Failed to update status", error: updateErr });
      }

      console.log(`✅ Complaint ${complaintId} status updated to ${status} by admin ${adminName}`);

      // Send email notification to reporter
      let emailSubject = "";
      let emailMessage = "";
      let emailColor = "";

      if (status === 'in_progress') {
        emailSubject = "Work Started on Your Complaint - Campus Entry Guide";
        emailMessage = "Good news! The admin team has started working on your complaint.";
        emailColor = "#2196F3";
      } else if (status === 'resolved') {
        emailSubject = "Complaint Resolved - Campus Entry Guide";
        emailMessage = "Great news! Your complaint has been marked as resolved by the admin team.";
        emailColor = "#4CAF50";
      }

      if (emailSubject) {
        const mailOptions = {
          to: complaint.reported_by_email,
          subject: emailSubject,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: ${emailColor}; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: ${emailColor}; padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">${status === 'in_progress' ? '🔧' : '✅'} Status Update</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${complaint.reported_by_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  ${emailMessage}
                </p>
                
                <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #333; margin: 0 0 10px 0;">Complaint Details:</h4>
                  <p style="margin: 5px 0;"><strong>Title:</strong> ${complaint.title}</p>
                  <p style="margin: 5px 0;"><strong>Category:</strong> ${complaint.category}</p>
                  <p style="margin: 5px 0;"><strong>Status:</strong> ${status === 'in_progress' ? 'In Progress' : 'Resolved'}</p>
                </div>
                
                ${adminResponse ? `
                <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #2e7d32; margin: 0 0 10px 0;">Admin Response:</h4>
                  <p style="color: #1b5e20; margin: 0;">${adminResponse}</p>
                </div>
                ` : ''}
                
                ${status === 'resolved' ? `
                <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
                  <p style="color: #856404; margin: 0; font-size: 14px;">
                    <strong>⚠️ Next Step:</strong><br>
                    Please verify in the app if the issue is actually resolved. If verified, you can allow admin to delete this complaint.
                  </p>
                </div>
                ` : ''}
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr, info) => {
          if (mailErr) {
            console.error("⚠️ Failed to send status update email:", mailErr);
          } else {
            console.log("✅ Status update email sent to:", complaint.reported_by_email);
          }
        });
      }

      res.status(200).json({
        message: "Complaint status updated successfully",
      });
    });
  });
});

// 📍 VERIFY COMPLAINT BY REPORTER
app.post("/verify-complaint", (req, res) => {
  const { complaintId, userId, userRole, allowAdminDelete } = req.body;

  if (!complaintId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    // Verify ownership
    if (complaint.reported_by_id !== userId || complaint.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only verify your own complaints" });
    }

    // Check if already verified
    if (complaint.verified_by_reporter) {
      return res.status(400).json({ message: "Complaint already verified" });
    }

    // Update verification
    const updateSql = `
      UPDATE complaints 
      SET verified_by_reporter = 1, verified_at = NOW(), allow_admin_delete = ?
      WHERE id = ?
    `;

    db.query(updateSql, [allowAdminDelete ? 1 : 0, complaintId], (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to verify complaint:", updateErr);
        return res.status(500).json({ message: "Failed to verify complaint", error: updateErr });
      }

      console.log(`✅ Complaint ${complaintId} verified by reporter ${userId}`);

      // If admin deletion is allowed, notify admin
      if (allowAdminDelete) {
        db.query(`SELECT email FROM admin_registration WHERE id = 1 LIMIT 1`, (adminErr, adminResults) => {
          if (!adminErr && adminResults.length > 0) {
            const adminMailOptions = {
              to: adminResults[0].email,
              subject: "Complaint Ready for Deletion - Campus Entry Guide",
              html: `
                <div style="font-family: Arial, sans-serif;">
                  <h2>Complaint Verified & Ready for Deletion</h2>
                  <p><strong>Title:</strong> ${complaint.title}</p>
                  <p><strong>Reporter:</strong> ${complaint.reported_by_name}</p>
                  <p>The reporter has verified the resolution and allowed deletion.</p>
                </div>
              `,
            };
            mailTransporter.sendMail(adminMailOptions);
          }
        });
      }

      res.status(200).json({
        message: "Complaint verified successfully",
      });
    });
  });
});

// 📍 UPDATE COMPLAINT (By Reporter - Only Pending Status)
app.post("/update-complaint", (req, res) => {
  const {
    complaintId,
    userId,
    userRole,
    title,
    description,
    category,
    location,
    priority,
    image
  } = req.body;

  if (!complaintId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    // Verify ownership
    if (complaint.reported_by_id !== userId || complaint.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only edit your own complaints" });
    }

    // Check if editable
    if (complaint.status !== 'pending') {
      return res.status(400).json({ message: "Can only edit complaints with pending status" });
    }

    // Build update query
    let updateFields = [];
    let updateValues = [];

    if (title) {
      updateFields.push("title = ?");
      updateValues.push(title);
    }
    if (description) {
      updateFields.push("description = ?");
      updateValues.push(description);
    }
    if (category) {
      updateFields.push("category = ?");
      updateValues.push(category);
    }
    if (location) {
      updateFields.push("location = ?");
      updateValues.push(location);
    }
    if (priority) {
      updateFields.push("priority = ?");
      updateValues.push(priority);
    }
    if (image !== undefined) {
      updateFields.push("image = ?");
      updateValues.push(image);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    updateValues.push(complaintId);
    const updateSql = `UPDATE complaints SET ${updateFields.join(", ")} WHERE id = ?`;

    db.query(updateSql, updateValues, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update complaint:", updateErr);
        return res.status(500).json({ message: "Failed to update complaint", error: updateErr });
      }

      console.log(`✅ Complaint ${complaintId} updated`);

      res.status(200).json({
        message: "Complaint updated successfully",
      });
    });
  });
});

// 📍 DELETE COMPLAINT
app.post("/delete-complaint", (req, res) => {
  const { complaintId, userId, userRole } = req.body;

  if (!complaintId || !userId || !userRole) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Get complaint details
  db.query(`SELECT * FROM complaints WHERE id = ?`, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Complaint not found" });
    }

    const complaint = results[0];

    // Admin can delete if reporter allowed
    if (userRole === 'Admin') {
      if (!complaint.allow_admin_delete) {
        return res.status(403).json({ message: "Reporter has not allowed deletion yet" });
      }

      db.query(`DELETE FROM complaints WHERE id = ?`, [complaintId], (delErr) => {
        if (delErr) {
          console.error("❌ Failed to delete complaint:", delErr);
          return res.status(500).json({ message: "Failed to delete complaint", error: delErr });
        }

        console.log(`✅ Admin deleted complaint ${complaintId}`);
        res.status(200).json({ message: "Complaint deleted successfully by admin" });
      });
      return;
    }

    // Reporter can delete before verification
    if (complaint.reported_by_id !== userId || complaint.reported_by_role !== userRole) {
      return res.status(403).json({ message: "You can only delete your own complaints" });
    }

    if (complaint.verified_by_reporter) {
      return res.status(400).json({ message: "Cannot delete after verification" });
    }

    db.query(`DELETE FROM complaints WHERE id = ?`, [complaintId], (delErr) => {
      if (delErr) {
        console.error("❌ Failed to delete complaint:", delErr);
        return res.status(500).json({ message: "Failed to delete complaint", error: delErr });
      }

      console.log(`✅ Reporter deleted complaint ${complaintId}`);
      res.status(200).json({ message: "Complaint deleted successfully" });
    });
  });
});

// 📍 ADD COMMENT TO COMPLAINT
app.post("/add-complaint-comment", (req, res) => {
  const { complaintId, userId, userName, userRole, comment } = req.body;

  console.log("📝 Adding comment:", {
    complaintId,
    userId,
    userName,
    userRole,
    comment: comment.substring(0, 50) + '...'
  });

  if (!complaintId || !userId || !userName || !userRole || !comment) {
    console.log("❌ Missing fields:", { complaintId, userId, userName, userRole, hasComment: !!comment });
    return res.status(400).json({ message: "Required fields missing" });
  }

  const sql = `
    INSERT INTO complaint_comments (complaint_id, user_id, user_name, user_role, comment, created_at)
    VALUES (?, ?, ?, ?, ?, NOW())
  `;

  db.query(sql, [complaintId, userId, userName, userRole, comment], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to add comment", error: err });
    }

    console.log(`✅ Comment added to complaint ${complaintId} by ${userName} (${userRole})`);

    res.status(201).json({
      message: "Comment added successfully",
      commentId: result.insertId,
    });
  });
});

// 📍 GET TOTAL COMPLAINT COUNT (For Badge Display)
app.post("/get-total-complaints-count", (req, res) => {
  const { userRole, status } = req.body;

  let sql = `SELECT COUNT(*) as totalCount FROM complaints WHERE is_active = 1`;
  let params = [];

  // If status filter is provided
  if (status && status !== 'all') {
    sql += ` AND status = ?`;
    params.push(status);
  }

  console.log('📊 Fetching total complaints count');
  console.log('   SQL:', sql);
  console.log('   Params:', params);

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch count", error: err });
    }

    const totalCount = results[0].totalCount || 0;
    console.log(`✅ Total complaints: ${totalCount}`);

    res.status(200).json({
      message: "Count fetched successfully",
      totalCount: totalCount,
    });
  });
});


// 📍 MARK ALL COMPLAINTS AS VIEWED
app.post("/mark-all-complaints-viewed", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  console.log(`👁️ Marking all complaints as viewed for user ${userId} (${userRole})`);

  const sql = `
    INSERT INTO complaint_views (user_id, user_role, last_viewed_at)
    VALUES (?, ?, NOW())
    ON DUPLICATE KEY UPDATE last_viewed_at = NOW()
  `;

  db.query(sql, [userId, userRole], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to mark as viewed", error: err });
    }

    console.log(`✅ All complaints marked as viewed for user ${userId}`);

    res.status(200).json({
      message: "All complaints marked as viewed",
    });
  });
});

// 📍 GET UNVIEWED COMPLAINTS COUNT (For Badge)
app.post("/get-unviewed-complaints-count", (req, res) => {
  const { userId, userRole } = req.body;

  if (!userId || !userRole) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const sql = `
    SELECT COUNT(*) as unviewedCount
    FROM complaints c
    LEFT JOIN complaint_views cv ON cv.user_id = ? AND cv.user_role = ?
    WHERE c.is_active = 1
      AND (cv.last_viewed_at IS NULL OR c.created_at > cv.last_viewed_at)
  `;

  db.query(sql, [userId, userRole], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch count", error: err });
    }

    const unviewedCount = results[0].unviewedCount || 0;
    console.log(`✅ Unviewed complaints for user ${userId}: ${unviewedCount}`);

    res.status(200).json({
      message: "Unviewed count fetched successfully",
      unviewedCount: unviewedCount,
    });
  });
});


// 📍 GET COMPLAINT COMMENTS
app.post("/get-complaint-comments", (req, res) => {
  const { complaintId } = req.body;

  if (!complaintId) {
    return res.status(400).json({ message: "Complaint ID is required" });
  }

  const sql = `
    SELECT 
      id,
      complaint_id,
      user_id,
      user_name,
      user_role,
      comment,
      created_at
    FROM complaint_comments 
    WHERE complaint_id = ?
    ORDER BY created_at ASC
  `;

  db.query(sql, [complaintId], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch comments", error: err });
    }

    console.log(`✅ Fetched ${results.length} comments for complaint ${complaintId}`);
    
    // Log each comment to debug
    results.forEach(comment => {
      console.log(`   Comment by ${comment.user_name} (${comment.user_role}): ${comment.comment.substring(0, 30)}...`);
    });

    res.status(200).json({
      message: "Comments fetched successfully",
      comments: results,
    });
  });
});

console.log("✅ Complaint System endpoints initialized");



// ================= ADD THESE ENDPOINTS TO YOUR server.js =================
// Add after the complaint system endpoints (around line 1800+)


// ================= GET ALL ACTIVE REMINDERS (FOR BACKGROUND SERVICE) =================
// ================= GET ALL ACTIVE REMINDERS (FIXED DATA STRUCTURE) =================
app.post("/get-all-active-reminders", (req, res) => {
  const sql = `
    SELECT 
      r.id as reminder_id,
      r.schedule_id,
      r.user_id,
      r.user_role,
      r.reminder_minutes,
      r.notification_tone,
      r.vibration_pattern,
      r.repeat_type,
      r.is_enabled,
      s.subject_name,
      s.day_of_week,
      s.start_time,
      s.end_time,
      s.room_number,
      s.degree,
      s.section
    FROM class_reminders r
    JOIN class_schedules s ON r.schedule_id = s.id
    WHERE r.is_enabled = 1 AND s.is_active = 1
    ORDER BY s.start_time ASC
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch reminders", error: err });
    }

    console.log(`✅ Fetched ${results.length} active reminders`);

    res.status(200).json({
      message: "Active reminders fetched",
      reminders: results,
    });
  });
});

// ================= LOG REMINDER TRIGGERED =================
app.post("/log-reminder-triggered", (req, res) => {
  const { schedule_id, triggered_at } = req.body;

  const sql = `
    INSERT INTO reminder_logs (schedule_id, triggered_at)
    VALUES (?, ?)
  `;

  db.query(sql, [schedule_id, triggered_at], (err) => {
    if (err) {
      console.error("⚠️ Error logging reminder:", err);
      return res.status(500).json({ message: "Failed to log reminder" });
    }

    console.log(`📊 Logged reminder for schedule ${schedule_id}`);
    res.status(200).json({ message: "Reminder logged" });
  });
});

// ================= CLASS REMINDER ENDPOINTS =================

// 📍 CREATE/UPDATE REMINDER
app.post("/set-schedule-reminder", (req, res) => {
  const {
    schedule_id,
    user_id,
    user_role,
    reminder_minutes,
    notification_tone,
    vibration_pattern,
    repeat_type,
    is_enabled
  } = req.body;

  console.log('🔔 Setting reminder:', {
    schedule_id,
    user_id,
    user_role,
    reminder_minutes,
    is_enabled
  });

  if (!schedule_id || !user_id || !user_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  // Check if reminder already exists
  const checkSql = `SELECT id FROM class_reminders WHERE schedule_id = ? AND user_id = ?`;
  
  db.query(checkSql, [schedule_id, user_id], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Database Error:", checkErr);
      return res.status(500).json({ message: "Database error", error: checkErr });
    }

    if (checkResults.length > 0) {
      // Update existing reminder
      const updateSql = `
        UPDATE class_reminders 
        SET reminder_minutes = ?, notification_tone = ?, vibration_pattern = ?, 
            repeat_type = ?, is_enabled = ?, updated_at = NOW()
        WHERE schedule_id = ? AND user_id = ?
      `;

      db.query(
        updateSql,
        [
          reminder_minutes || 10,
          notification_tone || 'default',
          vibration_pattern || 'short',
          repeat_type || 'daily',
          is_enabled !== undefined ? is_enabled : 1,
          schedule_id,
          user_id
        ],
        (updateErr, updateResult) => {
          if (updateErr) {
            console.error("❌ Failed to update reminder:", updateErr);
            return res.status(500).json({ message: "Failed to update reminder", error: updateErr });
          }

          console.log(`✅ Reminder updated for schedule ${schedule_id}`);

          res.status(200).json({
            message: "Reminder updated successfully",
            reminderId: checkResults[0].id,
          });
        }
      );
    } else {
      // Create new reminder
      const insertSql = `
        INSERT INTO class_reminders 
        (schedule_id, user_id, user_role, reminder_minutes, notification_tone, 
         vibration_pattern, repeat_type, is_enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `;

      db.query(
        insertSql,
        [
          schedule_id,
          user_id,
          user_role,
          reminder_minutes || 10,
          notification_tone || 'default',
          vibration_pattern || 'short',
          repeat_type || 'daily',
          is_enabled !== undefined ? is_enabled : 1
        ],
        (insertErr, insertResult) => {
          if (insertErr) {
            console.error("❌ Failed to create reminder:", insertErr);
            return res.status(500).json({ message: "Failed to create reminder", error: insertErr });
          }

          console.log(`✅ Reminder created for schedule ${schedule_id} (ID: ${insertResult.insertId})`);

          res.status(201).json({
            message: "Reminder created successfully",
            reminderId: insertResult.insertId,
          });
        }
      );
    }
  });
});

// 📍 GET USER'S REMINDERS
app.post("/get-schedule-reminders", (req, res) => {
  const { user_id, user_role, schedule_id } = req.body;

  if (!user_id || !user_role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  let sql = `
    SELECT r.*, s.subject_name, s.day_of_week, s.start_time, s.room_number
    FROM class_reminders r
    JOIN class_schedules s ON r.schedule_id = s.id
    WHERE r.user_id = ? AND r.user_role = ?
  `;
  let params = [user_id, user_role];

  if (schedule_id) {
    sql += ` AND r.schedule_id = ?`;
    params.push(schedule_id);
  }

  sql += ` ORDER BY s.day_of_week, s.start_time`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch reminders", error: err });
    }

    console.log(`✅ Fetched ${results.length} reminders for user ${user_id}`);

    res.status(200).json({
      message: "Reminders fetched successfully",
      reminders: results,
    });
  });
});

// 📍 GET SINGLE REMINDER
app.post("/get-single-reminder", (req, res) => {
  const { schedule_id, user_id } = req.body;

  if (!schedule_id || !user_id) {
    return res.status(400).json({ message: "Schedule ID and User ID are required" });
  }

  const sql = `
    SELECT * FROM class_reminders 
    WHERE schedule_id = ? AND user_id = ?
    LIMIT 1
  `;

  db.query(sql, [schedule_id, user_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(200).json({
        message: "No reminder found",
        reminder: null,
      });
    }

    res.status(200).json({
      message: "Reminder fetched successfully",
      reminder: results[0],
    });
  });
});

// 📍 DELETE REMINDER
app.post("/delete-schedule-reminder", (req, res) => {
  const { schedule_id, user_id } = req.body;

  if (!schedule_id || !user_id) {
    return res.status(400).json({ message: "Schedule ID and User ID are required" });
  }

  const sql = `DELETE FROM class_reminders WHERE schedule_id = ? AND user_id = ?`;

  db.query(sql, [schedule_id, user_id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to delete reminder", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Reminder not found" });
    }

    console.log(`✅ Reminder deleted for schedule ${schedule_id}`);

    res.status(200).json({
      message: "Reminder deleted successfully",
    });
  });
});

// 📍 TOGGLE REMINDER ON/OFF
app.post("/toggle-schedule-reminder", (req, res) => {
  const { schedule_id, user_id, is_enabled } = req.body;

  if (!schedule_id || !user_id || is_enabled === undefined) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  const sql = `
    UPDATE class_reminders 
    SET is_enabled = ?, updated_at = NOW()
    WHERE schedule_id = ? AND user_id = ?
  `;

  db.query(sql, [is_enabled ? 1 : 0, schedule_id, user_id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to toggle reminder", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Reminder not found" });
    }

    console.log(`✅ Reminder ${is_enabled ? 'enabled' : 'disabled'} for schedule ${schedule_id}`);

    res.status(200).json({
      message: `Reminder ${is_enabled ? 'enabled' : 'disabled'} successfully`,
    });
  });
});

// 📍 GET PDF FOR VIEWING
// ================= GET PDF FOR VIEWING (FIXED) =================
app.post("/get-timetable-pdf", (req, res) => {
  const { user_id, user_role } = req.body;

  if (!user_id || !user_role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  // ✅ FIX: Remove created_at from SELECT (column doesn't exist)
  const sql = `
    SELECT 
      id, pdf_base64, pdf_filename, shift, semester, version
    FROM timetable_uploads
    WHERE user_id = ? AND user_role = ? AND status = 'completed'
    ORDER BY id DESC
    LIMIT 1
  `;

  db.query(sql, [user_id, user_role], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "No timetable PDF found" });
    }

    const upload = results[0];

    // Update view count
    db.query(
      `UPDATE timetable_uploads SET pdf_view_count = pdf_view_count + 1, last_viewed_at = NOW() WHERE id = ?`,
      [upload.id]
    );

    console.log(`✅ PDF retrieved for user ${user_id} (Upload ID: ${upload.id})`);

    res.status(200).json({
      message: "PDF retrieved successfully",
      pdf: {
        id: upload.id,
        base64: upload.pdf_base64,
        filename: upload.pdf_filename,
        shift: upload.shift,
        semester: upload.semester,
        version: upload.version,
      },
    });
  });
});

console.log("✅ Class Reminder endpoints initialized");



// ================= CLASS SCHEDULING ENDPOINTS =================

// ✅ REPLACE THE /create-class-schedule ENDPOINT WITH THIS
app.post("/create-class-schedule", (req, res) => {
  const {
    subject_name,
    class_code,
    description,
    day_of_week,
    start_time,
    end_time,
    room_number,
    building,
    degree,
    section,
    semester,
    semester_no,  // ✅ ADDED
    teacher_id,
    teacher_name,
    teacher_email,
    teacher_department,
    created_by_id,
    created_by_role
  } = req.body;

  console.log('📝 Create schedule request:', {
    subject_name,
    degree,
    section,
    semester_no,  // ✅ LOG THIS
    created_by_role
  });

  if (!subject_name || !day_of_week || !start_time || !end_time || !room_number || 
      !degree || !section || !semester_no || !teacher_id || !teacher_name || !created_by_id || !created_by_role) {
    console.log('❌ Missing required fields');
    return res.status(400).json({ message: "Required fields missing" });
  }

  if (created_by_role !== 'Teacher' && created_by_role !== 'Admin' && created_by_role !== 'Student') {
    return res.status(403).json({ message: "Only Teachers, Admins, and Students can create schedules" });
  }

  const sql = `
    INSERT INTO class_schedules
    (subject_name, class_code, description, day_of_week, start_time, end_time,
     room_number, building, degree, section, semester, semester_no,
     teacher_id, teacher_name, teacher_email, teacher_department,
     created_by_id, created_by_role)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;

  db.query(
    sql,
    [subject_name, class_code || null, description || null, day_of_week, start_time, end_time,
     room_number, building || null, degree, section, semester || null, semester_no,
     teacher_id, teacher_name, teacher_email || null, teacher_department || null,
     created_by_id, created_by_role],
    (err, result) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err });
      }

      console.log(`✅ Class schedule created by ${teacher_name} (ID: ${result.insertId})`);

      if (teacher_email) {
        const mailOptions = {
          to: teacher_email,
          subject: "New Class Schedule Created - Campus Entry Guide",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: #667eea; margin: 0;">Campus Entry Guide</h1>
                </div>
                
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                  <h2 style="color: white; margin: 0;">📅 Class Schedule Created!</h2>
                </div>
                
                <h3 style="color: #333; margin-bottom: 15px;">Hi ${teacher_name},</h3>
                
                <p style="color: #666; font-size: 16px; line-height: 1.6;">
                  A new class schedule has been created for you.
                </p>
                
                <div style="background-color: #f0f4ff; padding: 20px; border-radius: 8px; margin: 25px 0;">
                  <h4 style="color: #667eea; margin: 0 0 10px 0;">Schedule Details:</h4>
                  <p style="margin: 5px 0;"><strong>Subject:</strong> ${subject_name}</p>
                  <p style="margin: 5px 0;"><strong>Class Code:</strong> ${class_code || 'N/A'}</p>
                  <p style="margin: 5px 0;"><strong>Day:</strong> ${day_of_week}</p>
                  <p style="margin: 5px 0;"><strong>Time:</strong> ${start_time} - ${end_time}</p>
                  <p style="margin: 5px 0;"><strong>Room:</strong> ${room_number}</p>
                  <p style="margin: 5px 0;"><strong>Section:</strong> ${degree}-${section}</p>
                  <p style="margin: 5px 0;"><strong>Semester:</strong> ${semester_no}</p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                  <p style="color: #999; font-size: 12px; margin: 0;">
                    © 2025 Campus Entry Guide. All rights reserved.
                  </p>
                </div>
              </div>
            </div>
          `,
        };

        mailTransporter.sendMail(mailOptions, (mailErr) => {
          if (mailErr) {
            console.error("⚠️ Failed to send schedule email:", mailErr);
          } else {
            console.log("✅ Schedule email sent to:", teacher_email);
          }
        });
      }

      res.status(201).json({
        message: "Class schedule created successfully",
        scheduleId: result.insertId,
      });
    }
  );
});

// 📍 GET TEACHER SCHEDULES
app.post("/get-teacher-schedules", (req, res) => {
  const { teacher_id, day_of_week } = req.body;

  console.log('🔍 Fetching schedules for teacher:', teacher_id);

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  let sql = `
    SELECT * FROM class_schedules 
    WHERE teacher_id = ? AND is_active = 1
  `;
  let params = [teacher_id];

  if (day_of_week && day_of_week !== 'all') {
    sql += ` AND day_of_week = ?`;
    params.push(day_of_week);
  }

  sql += ` ORDER BY 
    FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'),
    start_time ASC`;

  console.log('📍 SQL:', sql);
  console.log('📍 Params:', params);

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch schedules", error: err });
    }

    console.log(`✅ Fetched ${results.length} schedules for teacher ${teacher_id}`);

    if (results.length > 0) {
      console.log('📋 Found schedules:');
      results.forEach(r => {
        console.log(`   - ${r.day_of_week}: ${r.subject_name} for ${r.degree}-${r.section} at ${r.start_time}`);
      });
    }

    const groupedSchedules = {
      Monday: [],
      Tuesday: [],
      Wednesday: [],
      Thursday: [],
      Friday: [],
      Saturday: []
    };

    results.forEach(schedule => {
      groupedSchedules[schedule.day_of_week].push(schedule);
    });

    res.status(200).json({
      message: "Schedules fetched successfully",
      schedules: results,
      groupedSchedules: groupedSchedules,
      totalClasses: results.length
    });
  });
});

// ✅ FIND AND REPLACE /get-student-schedules ENDPOINT IN server.js

app.post("/get-student-schedules", (req, res) => {
  const { degree, section, semesterNo, day_of_week } = req.body;

  console.log('📊 Fetching schedules for:');
  console.log('   Degree:', degree);
  console.log('   Section:', section);
  console.log('   Semester No:', semesterNo);
  console.log('   Day:', day_of_week);

  if (!degree || !section || !semesterNo) {
    return res.status(400).json({ message: "Degree, section, and semester are required" });
  }

  // ✅ CRITICAL: Filter by degree + section + semester_no
  let sql = `
    SELECT * FROM class_schedules 
    WHERE degree = ? AND section = ? AND semester_no = ? AND is_active = 1
  `;
  let params = [degree, section, semesterNo];

  if (day_of_week && day_of_week !== 'all') {
    sql += ` AND day_of_week = ?`;
    params.push(day_of_week);
  }

  sql += ` ORDER BY 
    FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'),
    start_time ASC`;

  console.log('📍 SQL Query:', sql);
  console.log('📍 Params:', params);

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch schedules", error: err });
    }

    console.log(`✅ Fetched ${results.length} schedules for ${degree}-${section} Semester ${semesterNo}`);
    
    // ✅ LOG WHAT WAS FOUND
    if (results.length > 0) {
      console.log('📋 Found schedules:');
      results.forEach(r => {
        console.log(`   - ${r.day_of_week}: ${r.subject_name} at ${r.start_time}`);
      });
    }

    const groupedSchedules = {
      Monday: [],
      Tuesday: [],
      Wednesday: [],
      Thursday: [],
      Friday: [],
      Saturday: []
    };

    results.forEach(schedule => {
      groupedSchedules[schedule.day_of_week].push(schedule);
    });

    res.status(200).json({
      message: "Schedules fetched successfully",
      schedules: results,
      groupedSchedules: groupedSchedules,
      totalClasses: results.length
    });
  });
});

// 📍 UPDATE CLASS SCHEDULE
app.post("/update-class-schedule", (req, res) => {
  const {
    schedule_id,
    user_id,
    user_role,
    subject_name,
    class_code,
    description,
    day_of_week,
    start_time,
    end_time,
    room_number,
    building,
    semester
  } = req.body;

  if (!schedule_id || !user_id || !user_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  db.query(`SELECT * FROM class_schedules WHERE id = ?`, [schedule_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Schedule not found" });
    }

    const schedule = results[0];

    if (user_role !== 'Admin' && schedule.created_by_id !== user_id) {
      return res.status(403).json({ message: "You can only edit your own schedules" });
    }

    let updateFields = [];
    let updateValues = [];

    if (subject_name) {
      updateFields.push("subject_name = ?");
      updateValues.push(subject_name);
    }
    if (class_code !== undefined) {
      updateFields.push("class_code = ?");
      updateValues.push(class_code);
    }
    if (description !== undefined) {
      updateFields.push("description = ?");
      updateValues.push(description);
    }
    if (day_of_week) {
      updateFields.push("day_of_week = ?");
      updateValues.push(day_of_week);
    }
    if (start_time) {
      updateFields.push("start_time = ?");
      updateValues.push(start_time);
    }
    if (end_time) {
      updateFields.push("end_time = ?");
      updateValues.push(end_time);
    }
    if (room_number) {
      updateFields.push("room_number = ?");
      updateValues.push(room_number);
    }
    if (building !== undefined) {
      updateFields.push("building = ?");
      updateValues.push(building);
    }
    if (semester !== undefined) {
      updateFields.push("semester = ?");
      updateValues.push(semester);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    updateFields.push("updated_at = NOW()");
    updateValues.push(schedule_id);

    const updateSql = `UPDATE class_schedules SET ${updateFields.join(", ")} WHERE id = ?`;

    db.query(updateSql, updateValues, (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Failed to update schedule:", updateErr);
        return res.status(500).json({ message: "Failed to update schedule", error: updateErr });
      }

      console.log(`✅ Schedule ${schedule_id} updated`);

      res.status(200).json({
        message: "Schedule updated successfully",
      });
    });
  });
});

// 📍 DELETE CLASS SCHEDULE
app.post("/delete-class-schedule", (req, res) => {
  const { schedule_id, user_id, user_role } = req.body;

  if (!schedule_id || !user_id || !user_role) {
    return res.status(400).json({ message: "Required fields missing" });
  }

  db.query(`SELECT * FROM class_schedules WHERE id = ?`, [schedule_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Schedule not found" });
    }

    const schedule = results[0];

    if (user_role !== 'Admin' && schedule.created_by_id !== user_id) {
      return res.status(403).json({ message: "You can only delete your own schedules" });
    }

    db.query(`DELETE FROM class_schedules WHERE id = ?`, [schedule_id], (delErr) => {
      if (delErr) {
        console.error("❌ Failed to delete schedule:", delErr);
        return res.status(500).json({ message: "Failed to delete schedule", error: delErr });
      }

      console.log(`✅ Schedule ${schedule_id} deleted`);
      res.status(200).json({ message: "Schedule deleted successfully" });
    });
  });
});

// 📍 GET TODAY'S CLASSES (For Dashboard)
app.post("/get-today-classes", (req, res) => {
  const { user_id, user_role, degree, section } = req.body;

  if (!user_id || !user_role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const today = days[new Date().getDay()];

  let sql, params;

  if (user_role === 'Teacher') {
    sql = `
      SELECT * FROM class_schedules 
      WHERE teacher_id = ? AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;
    params = [user_id, today];
  } else if (user_role === 'Student') {
    if (!degree || !section) {
      return res.status(400).json({ message: "Degree and section are required for students" });
    }
    sql = `
      SELECT * FROM class_schedules 
      WHERE degree = ? AND section = ? AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;
    params = [degree, section, today];
  } else {
    return res.status(400).json({ message: "Invalid role for this endpoint" });
  }

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch today's classes", error: err });
    }

    console.log(`✅ Fetched ${results.length} classes for today (${today})`);

    res.status(200).json({
      message: "Today's classes fetched successfully",
      classes: results,
      day: today,
      totalClasses: results.length
    });
  });
});

// 📍 GET SCHEDULE STATISTICS
app.post("/get-schedule-stats", (req, res) => {
  const { user_id, user_role, degree, section } = req.body;

  if (!user_id || !user_role) {
    return res.status(400).json({ message: "User ID and role are required" });
  }

  let sql, params;

  if (user_role === 'Teacher') {
    sql = `
      SELECT 
        COUNT(*) as total_classes,
        COUNT(DISTINCT CONCAT(degree, '-', section)) as total_sections,
        COUNT(DISTINCT subject_name) as total_subjects,
        COUNT(DISTINCT day_of_week) as teaching_days
      FROM class_schedules 
      WHERE teacher_id = ? AND is_active = 1
    `;
    params = [user_id];
  } else if (user_role === 'Student') {
    if (!degree || !section) {
      return res.status(400).json({ message: "Degree and section are required for students" });
    }
    sql = `
      SELECT 
        COUNT(*) as total_classes,
        COUNT(DISTINCT teacher_name) as total_teachers,
        COUNT(DISTINCT subject_name) as total_subjects,
        COUNT(DISTINCT day_of_week) as class_days
      FROM class_schedules 
      WHERE degree = ? AND section = ? AND is_active = 1
    `;
    params = [degree, section];
  } else {
    return res.status(400).json({ message: "Invalid role" });
  }

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch statistics", error: err });
    }

    res.status(200).json({
      message: "Statistics fetched successfully",
      stats: results[0]
    });
  });
});

console.log("✅ Class Scheduling endpoints initialized");

// ================= AI PARSING FUNCTION (DEFINE ONCE!) =================
// ================= IMPROVED PDF PARSER - DROP-IN REPLACEMENT =================
// ================= REPLACE YOUR EXISTING parseTimetablePDF FUNCTION WITH THIS =================

async function parseTimetablePDF(pdfBase64, userRole, degree, section, semesterNo, teacherName) {
  try {
    console.log('📄 Starting IMPROVED PDF parsing...');
    console.log(`👤 User Role: ${userRole}`);
    
    if (userRole === 'Student') {
      console.log(`🎓 Student Info: ${degree}-${section}, Semester: ${semesterNo}`);
    } else if (userRole === 'Teacher') {
      console.log(`👨‍🏫 Teacher Name: ${teacherName}`);
    }
    
    const pdfBuffer = Buffer.from(pdfBase64, 'base64');
    const pdfData = await pdfParse(pdfBuffer);
    const text = pdfData.text;
    
    console.log('📝 PDF successfully parsed!');
    
    const schedules = [];
    const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);
    
    console.log(`📊 Total lines in PDF: ${lines.length}`);
    
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    // ✅ Detect shift
    let shift = 'Morning';
    const lowerText = text.toLowerCase();
    
    if (lowerText.includes('after/even') || lowerText.includes('evening')) {
      shift = 'Evening';
    } else if (lowerText.includes('morn')) {
      shift = 'Morning';
    }
    
    console.log(`🌅 Detected Shift: ${shift}`);
    
    // ✅ Extract metadata
    let semester = '';
    let version = '';
    
    const semesterMatch = text.match(/(Spring|Fall|Summer|Autumn)[-\s]*\d{4}/i);
    if (semesterMatch) {
      semester = semesterMatch[0].replace(/\s+/g, '-');
    }
    
    const versionMatch = text.match(/Ver(?:sion)?\.?\s*[\d.]+/i);
    if (versionMatch) {
      version = versionMatch[0];
    }
    
    console.log(`📊 Semester: ${semester}, Version: ${version}`);
    
    // ✅ Find ALL available sections
    const availableSections = [];
    for (const line of lines) {
      const match = line.match(/^([A-Z]{2,4})-(\d+)([A-Z])$/);
      if (match) {
        const [, deg, sem, sec] = match;
        const normalizedCode = `${deg}-${sem}${sec}`;
        
        if (!availableSections.some(s => s.fullCode === normalizedCode)) {
          availableSections.push({
            fullCode: normalizedCode,
            degree: deg,
            semester: sem,
            section: sec
          });
        }
      }
    }
    
    console.log(`\n📋 Available sections in PDF:`);
    availableSections.forEach(s => console.log(`   - ${s.fullCode}`));
    
    // ✅ IMPROVED: Extract time slots with validation
    const timeSlots = extractTimeSlotsImproved(lines, shift);
    
    console.log(`⏰ Extracted ${timeSlots.length} time slots:`);
    timeSlots.forEach((slot, i) => {
      console.log(`   Slot ${i + 1}: ${slot.start} - ${slot.end}`);
    });
    
    // ✅ ============== TEACHER MODE ==============
    if (userRole === 'Teacher') {
      console.log(`\n👨‍🏫 TEACHER MODE: Looking for classes taught by "${teacherName}"\n`);
      
      const normalizedTargetTeacher = teacherName.toLowerCase().trim();
      
      for (const day of days) {
        console.log(`\n📅 Processing ${day}...`);
        
        const dayLineIndex = lines.findIndex(line => line.toLowerCase() === day.toLowerCase());
        if (dayLineIndex === -1) {
          console.log(`   ❌ Day "${day}" not found`);
          continue;
        }
        
        console.log(`   ✅ Found day at line ${dayLineIndex}`);
        
        let nextDayIndex = lines.length;
        for (let i = dayLineIndex + 1; i < lines.length; i++) {
          if (days.some(d => lines[i].toLowerCase() === d.toLowerCase())) {
            nextDayIndex = i;
            break;
          }
        }
        
        for (const sectionInfo of availableSections) {
          const targetCode = sectionInfo.fullCode;
          
          let sectionLineIndex = -1;
          for (let i = dayLineIndex + 1; i < nextDayIndex; i++) {
            const line = lines[i];
            const normalizedLine = line.replace(/\s+/g, '');
            const normalizedTarget = targetCode.replace(/\s+/g, '');
            
            if (normalizedLine === normalizedTarget || line === targetCode) {
              sectionLineIndex = i;
              break;
            }
          }
          
          if (sectionLineIndex === -1) continue;
          
          // ✅ IMPROVED: Extract classes with better slot handling
          let classIndex = 0;
          let currentLine = sectionLineIndex + 1;
          
          while (currentLine < nextDayIndex && classIndex < timeSlots.length) {
            let classText = lines[currentLine];
            
            if (classText.match(/^[A-Z]{2,4}-\d+[A-Z]$/)) break;
            
            if (classText.match(/^(TGM |MS-|PhD-|Pre-Req)/i)) {
              console.log(`   ⏭️ Skipping special entry at slot ${classIndex + 1}`);
              currentLine++;
              classIndex++;
              continue;
            }
            
            // ✅ IMPROVED: Better multi-line collection
            let combinedText = classText;
            let k = currentLine + 1;
            let linesCollected = 0;
            
            while (k < nextDayIndex && linesCollected < 6) {
              const nextLine = lines[k];
              
              if (nextLine.match(/^[A-Z]{2,4}-\d+[A-Z]$/)) break;
              if (nextLine.match(/^(TGM |MS-|PhD-|Pre-Req|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)/i)) break;
              
              // ✅ IMPROVED: Check if entry is complete
              if (isCompleteClassEntry(combinedText)) {
                break;
              }
              
              combinedText += ' ' + nextLine;
              linesCollected++;
              k++;
            }
            
            // ✅ IMPROVED: Better parsing validation
            const parsed = parseClassEntryImproved(combinedText);
            
            if (parsed && parsed.subject && parsed.teacher) {
              const normalizedParsedTeacher = parsed.teacher.toLowerCase().trim();
              
              const isMatch = 
                normalizedParsedTeacher.includes(normalizedTargetTeacher) || 
                normalizedTargetTeacher.includes(normalizedParsedTeacher) ||
                normalizedParsedTeacher.split(/\s+/).some(part => 
                  normalizedTargetTeacher.includes(part) && part.length > 2
                );
              
              if (isMatch) {
                const schedule = {
                  subject_name: parsed.subject,
                  teacher_name: parsed.teacher,
                  room_number: parsed.room || 'TBA',
                  building: null,
                  day_of_week: day,
                  start_time: timeSlots[classIndex].start,
                  end_time: timeSlots[classIndex].end,
                  degree: sectionInfo.degree,
                  section: sectionInfo.section,
                  semester_no: sectionInfo.semester,
                  class_code: targetCode
                };
                
                schedules.push(schedule);
                console.log(`   ✅ Found class for ${teacherName}:`);
                console.log(`      📚 ${parsed.subject.substring(0, 40)}`);
                console.log(`      🎓 Section: ${targetCode}`);
                console.log(`      ⏰ ${timeSlots[classIndex].start} - ${timeSlots[classIndex].end}`);
                console.log(`      📍 ${parsed.room || 'TBA'}`);
              }
            } else if (!parsed || !parsed.subject) {
              console.log(`   ⏭️ Empty slot ${classIndex + 1} detected`);
            }
            
            classIndex++;
            currentLine = k;
          }
          
          // ✅ IMPROVED: Warn if slot count mismatch
          if (classIndex < timeSlots.length && currentLine < nextDayIndex) {
            console.log(`   ⚠️ Section ended early: ${classIndex}/${timeSlots.length} slots processed`);
          }
        }
      }
      
    } 
    // ✅ ============== STUDENT MODE ==============
    else {
      console.log(`\n🎓 STUDENT MODE: Looking for section ${degree}-${semesterNo}${section}\n`);
      
      for (const day of days) {
        console.log(`\n📅 Processing ${day}...`);
        
        const dayLineIndex = lines.findIndex(line => line.toLowerCase() === day.toLowerCase());
        if (dayLineIndex === -1) {
          console.log(`   ❌ Day "${day}" not found`);
          continue;
        }
        
        console.log(`   ✅ Found day at line ${dayLineIndex}`);
        
        const targetCode = `${degree}-${semesterNo}${section}`;
        console.log(`   🔍 Looking for: ${targetCode}`);
        
        let nextDayIndex = lines.length;
        for (let i = dayLineIndex + 1; i < lines.length; i++) {
          if (days.some(d => lines[i].toLowerCase() === d.toLowerCase())) {
            nextDayIndex = i;
            break;
          }
        }
        
        let sectionLineIndex = -1;
        for (let i = dayLineIndex + 1; i < nextDayIndex; i++) {
          const line = lines[i];
          const normalizedLine = line.replace(/\s+/g, '');
          const normalizedTarget = targetCode.replace(/\s+/g, '');
          
          if (normalizedLine === normalizedTarget || line === targetCode) {
            sectionLineIndex = i;
            console.log(`   ✅ Found section at line ${i}: ${line}`);
            break;
          }
        }
        
        if (sectionLineIndex === -1) {
          console.log(`   ❌ Section ${targetCode} NOT FOUND on ${day}`);
          continue;
        }
        
        // ✅ IMPROVED: Extract classes with better validation
        let classIndex = 0;
        let currentLine = sectionLineIndex + 1;
        
        console.log(`   📍 Extracting classes...`);
        
        while (currentLine < nextDayIndex && classIndex < timeSlots.length) {
          let classText = lines[currentLine];
          
          if (classText.match(/^[A-Z]{2,4}-\d+[A-Z]$/)) {
            console.log(`   ⏸️ Hit another section: "${classText}"`);
            break;
          }
          
          if (classText.match(/^(TGM |MS-|PhD-|Pre-Req)/i)) {
            console.log(`   ⏭️ Skipping special entry: "${classText.substring(0, 30)}"`);
            currentLine++;
            classIndex++;
            continue;
          }
          
          // ✅ IMPROVED: Better multi-line collection
          let combinedText = classText;
          let k = currentLine + 1;
          let linesCollected = 0;
          
          while (k < nextDayIndex && linesCollected < 6) {
            const nextLine = lines[k];
            
            if (nextLine.match(/^[A-Z]{2,4}-\d+[A-Z]$/)) break;
            if (nextLine.match(/^(TGM |MS-|PhD-|Pre-Req|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)/i)) break;
            
            // ✅ IMPROVED: Check if entry is complete
            if (isCompleteClassEntry(combinedText)) {
              break;
            }
            
            combinedText += ' ' + nextLine;
            linesCollected++;
            k++;
          }
          
          // ✅ IMPROVED: Better parsing validation
          const parsed = parseClassEntryImproved(combinedText);
          
          if (parsed && parsed.subject && parsed.subject.length >= 3) {
            const schedule = {
              subject_name: parsed.subject,
              teacher_name: parsed.teacher || 'TBA',
              room_number: parsed.room || 'TBA',
              building: null,
              day_of_week: day,
              start_time: timeSlots[classIndex].start,
              end_time: timeSlots[classIndex].end,
              degree: degree,
              section: section,
              semester_no: semesterNo,
              class_code: `${degree}-${semesterNo}${section}`
            };
            
            schedules.push(schedule);
            console.log(`   ✅ Slot ${classIndex + 1}: ${parsed.subject.substring(0, 40)}`);
            console.log(`      🧑 ${parsed.teacher || 'TBA'} | 📍 ${parsed.room || 'TBA'}`);
          } else {
            console.log(`   ⏭️ Empty slot ${classIndex + 1}: No valid class data`);
          }
          
          classIndex++;
          currentLine = k;
        }
        
        // ✅ IMPROVED: Warn if slot count mismatch
        if (classIndex < timeSlots.length) {
          console.log(`   ℹ️ Day ended with ${classIndex}/${timeSlots.length} slots processed`);
        }
      }
    }
    
    console.log(`\n📊 Total schedules parsed: ${schedules.length}`);
    
    // ✅ Remove duplicates
    const uniqueSchedules = [];
    const seen = new Set();
    
    for (const schedule of schedules) {
      const key = userRole === 'Teacher' 
        ? `${schedule.subject_name}-${schedule.day_of_week}-${schedule.start_time}-${schedule.degree}-${schedule.section}`
        : `${schedule.subject_name}-${schedule.day_of_week}-${schedule.start_time}`;
      
      if (!seen.has(key)) {
        seen.add(key);
        uniqueSchedules.push(schedule);
      }
    }
    
    console.log(`📊 Unique schedules: ${uniqueSchedules.length}\n`);
    
    return {
      shift: shift,
      semester: semester || 'Spring-2026',
      version: version || 'Ver 1.0',
      schedules: uniqueSchedules
    };
    
  } catch (error) {
    console.error("❌ PDF Parsing Error:", error);
    throw new Error(`Failed to parse PDF: ${error.message}`);
  }
}

// ✅ IMPROVED: Extract time slots with better validation
function extractTimeSlotsImproved(lines, shift) {
  const timeSlots = [];
  
  // Find header line (usually in first 50 lines)
  for (let i = 0; i < Math.min(lines.length, 50); i++) {
    const line = lines[i];
    
    // Look for lines with time ranges
    const timeRanges = line.match(/\d{1,2}:\d{2}\s*(?:AM|PM)?\s*-\s*\d{1,2}:\d{2}\s*(?:AM|PM)?/gi);
    
    if (timeRanges && timeRanges.length >= 4) {
      console.log(`⏰ Found time header at line ${i}: "${line.substring(0, 80)}"`);
      
      for (const range of timeRanges) {
        const parts = range.split('-');
        if (parts.length === 2) {
          const start = convertTo24HourAccurate(parts[0].trim(), shift);
          const end = convertTo24HourAccurate(parts[1].trim(), shift);
          
          if (start && end) {
            timeSlots.push({ start, end });
          }
        }
      }
      
      // ✅ IMPROVED: Validate extracted slots
      if (timeSlots.length >= 4 && timeSlots.length <= 8) {
        console.log(`✅ Valid time slots extracted: ${timeSlots.length} slots`);
        return timeSlots;
      } else if (timeSlots.length > 0) {
        console.log(`⚠️ Unusual slot count (${timeSlots.length}), trying next line...`);
        timeSlots.length = 0; // Reset and continue searching
      }
    }
  }
  
  // ✅ Fallback: Use standard time slots
  console.log('⚠️ Could not extract time slots from PDF, using fallback');
  
  if (shift === 'Evening') {
    return [
      { start: '13:00:00', end: '13:50:00' },
      { start: '14:00:00', end: '14:50:00' },
      { start: '15:00:00', end: '15:50:00' },
      { start: '16:00:00', end: '16:50:00' },
      { start: '16:50:00', end: '17:40:00' },
      { start: '17:40:00', end: '18:30:00' }
    ];
  } else {
    return [
      { start: '08:00:00', end: '08:50:00' },
      { start: '09:00:00', end: '09:50:00' },
      { start: '10:00:00', end: '10:50:00' },
      { start: '11:00:00', end: '11:50:00' },
      { start: '12:00:00', end: '12:50:00' },
      { start: '13:00:00', end: '13:50:00' }
    ];
  }
}

// ✅ IMPROVED: Better time conversion
function convertTo24HourAccurate(timeStr, shift) {
  if (!timeStr) return null;
  
  timeStr = timeStr.trim();
  
  const match = timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
  if (!match) return null;
  
  let hours = parseInt(match[1]);
  const minutes = parseInt(match[2]);
  const period = match[3] ? match[3].toUpperCase() : null;
  
  // ✅ Handle AM/PM explicitly
  if (period === 'PM' && hours < 12) {
    hours += 12;
  } else if (period === 'AM' && hours === 12) {
    hours = 0;
  }
  
  // ✅ If no AM/PM marker, use shift context
  if (!period) {
    if (shift === 'Evening') {
      if (hours >= 1 && hours <= 6) {
        hours += 12;
      }
    }
  }
  
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;
}

// ✅ NEW: Check if a class entry is complete
function isCompleteClassEntry(text) {
  if (!text || text.length < 5) return false;
  
  const openParens = (text.match(/\(/g) || []).length;
  const closeParens = (text.match(/\)/g) || []).length;
  
  // Complete if we have at least 2 pairs of parentheses (teacher + room) and they're balanced
  if (openParens >= 2 && openParens === closeParens) {
    // Also verify there's text before the first parenthesis (the subject)
    const firstParenIndex = text.indexOf('(');
    const subjectPart = text.substring(0, firstParenIndex).trim();
    return subjectPart.length >= 3;
  }
  
  return false;
}

// ✅ IMPROVED: Better class entry parser with validation
function parseClassEntryImproved(text) {
  if (!text || text.trim().length < 3) return null;
  
  text = text.replace(/\s+/g, ' ').trim();
  
  if (text.length < 5) return null;
  
  // ✅ Extract all parentheses content
  const parenthesesContent = [];
  const parenthesesMatches = text.match(/\(([^)]+)\)/g);
  
  if (parenthesesMatches) {
    parenthesesMatches.forEach(match => {
      parenthesesContent.push(match.replace(/[()]/g, '').trim());
    });
  }
  
  // ✅ Find subject (everything before first opening parenthesis)
  const firstParenIndex = text.indexOf('(');
  let subject = firstParenIndex > 0 ? text.substring(0, firstParenIndex).trim() : text;
  
  // Clean subject
  subject = subject.replace(/^\d+\)\s*/, ''); // Remove "103) " prefix
  subject = subject.replace(/\s+(GC|AI)\s+Section\s*-?[A-Z]/gi, ''); // Remove section markers
  subject = subject.trim();
  
  // ✅ IMPROVED: Better validation
  if (!subject || subject.length < 3) return null;
  if (subject.match(/^[()]+$/)) return null;
  if (subject.toLowerCase().includes('tgm ')) return null;
  if (subject.match(/^(Lab-|CL-|LT-|Room|Building)/i)) return null; // Don't treat room names as subjects
  
  // ✅ Identify teacher and room from parentheses
  let teacher = null;
  let room = null;
  
  for (const content of parenthesesContent) {
    // Check if this is a room (more specific patterns)
    if (/^(Lab-|CL-|LT-|HRD|Room\s*|R-|CR-|\d+[A-Z]?$)/i.test(content)) {
      if (!room) room = content;
    } 
    // Check if it looks like a building/floor indicator
    else if (/^(Building|Floor|Wing|Block)/i.test(content)) {
      // Skip building indicators for now
      continue;
    }
    // It's likely a teacher name
    else if (content.length > 2) {
      if (!teacher) teacher = content;
    }
  }
  
  // ✅ IMPROVED: Don't return entry if we only have a room number
  if (subject.length < 5 && parenthesesContent.length === 0) {
    return null;
  }
  
  return {
    subject: subject,
    teacher: teacher,
    room: room
  };
}

// ================= UPDATED UPLOAD ENDPOINT =================
/// ================= UPDATED UPLOAD ENDPOINT FOR BOTH STUDENTS AND TEACHERS =================
// Replace the /upload-timetable endpoint in server.js

app.post("/upload-timetable", async (req, res) => {
  console.log('📤 Timetable upload request received!');
  
  const { userId, userRole, degree, section, semesterNo, teacherName, pdfBase64 } = req.body;

  console.log('📊 User ID:', userId);
  console.log('📊 User Role:', userRole);
  console.log('📊 Degree:', degree);
  console.log('📊 Section:', section);
  console.log('📊 Semester No:', semesterNo);
  console.log('📊 Teacher Name:', teacherName);
  console.log('📊 Has PDF data:', !!pdfBase64);

  if (!userId || !userRole || !pdfBase64) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  // ✅ For students, require degree/section/semester
  if (userRole === 'Student' && (!degree || !section || !semesterNo)) {
    return res.status(400).json({ message: "Degree, section, and semester required for students" });
  }

  // ✅ For teachers, teacherName is optional (we'll use it from parsing or default)
  
  try {
    const uploadSql = `
      INSERT INTO timetable_uploads 
      (user_id, user_role, pdf_filename, pdf_base64, shift, student_degree, student_section, teacher_name, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'processing')
    `;

    db.query(
      uploadSql,
      [userId, userRole, 'timetable.pdf', pdfBase64, 'Morning', degree || null, section || null, teacherName || null],
      async (err, result) => {
        if (err) {
          console.error("❌ Database Error:", err);
          return res.status(500).json({ message: "Failed to create upload record", error: err.message });
        }

        const uploadId = result.insertId;
        console.log(`✅ Upload record created with ID: ${uploadId}`);

        try {
          // ✅ Parse PDF - works for both teachers and students
          const parsedData = await parseTimetablePDF(
            pdfBase64,
            userRole,
            degree,
            section,
            semesterNo,
            teacherName
          );

          console.log(`✅ Parsed ${parsedData.schedules.length} classes from PDF`);

          // ✅ Delete old schedules based on role
          let deleteSql, deleteParams;
          
          if (userRole === 'Student') {
            // For students: delete by degree + section + semester
            deleteSql = `DELETE FROM class_schedules WHERE degree = ? AND section = ? AND semester_no = ? AND parsed_from_pdf = 1`;
            deleteParams = [degree, section, semesterNo];
          } else if (userRole === 'Teacher') {
            // For teachers: delete by teacher_id
            deleteSql = `DELETE FROM class_schedules WHERE teacher_id = ? AND parsed_from_pdf = 1`;
            deleteParams = [userId];
          }

          db.query(deleteSql, deleteParams, (delErr) => {
            if (delErr) {
              console.error("⚠️ Failed to delete old schedules:", delErr);
            } else {
              if (userRole === 'Student') {
                console.log(`🗑️ Deleted old schedules for ${degree}-${section} Semester ${semesterNo}`);
              } else {
                console.log(`🗑️ Deleted old schedules for teacher ${userId}`);
              }
            }

            let insertedCount = 0;
            const schedules = parsedData.schedules;

            if (schedules.length === 0) {
              db.query(
                `UPDATE timetable_uploads SET status = 'completed', processed_at = NOW(), entries_created = 0 WHERE id = ?`,
                [uploadId]
              );

              return res.status(200).json({
                message: "No classes found in timetable",
                uploadId: uploadId,
                totalClasses: 0
              });
            }

            console.log(`💾 Inserting ${schedules.length} schedules...`);

            schedules.forEach((schedule, index) => {
              const insertSql = `
                INSERT INTO class_schedules
                (subject_name, class_code, day_of_week, start_time, end_time, room_number, building,
                 degree, section, semester, semester_no, teacher_id, teacher_name,
                 created_by_id, created_by_role, upload_id, parsed_from_pdf, shift, version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
              `;

              const values = [
                schedule.subject_name,
                schedule.class_code || null,
                schedule.day_of_week,
                schedule.start_time,
                schedule.end_time,
                schedule.room_number,
                schedule.building || null,
                schedule.degree,
                schedule.section,
                parsedData.semester || null,
                schedule.semester_no,
                userRole === 'Teacher' ? userId : null, // ✅ Set teacher_id for teachers
                schedule.teacher_name,
                userId,
                userRole,
                uploadId,
                parsedData.shift,
                parsedData.version || null
              ];

              db.query(insertSql, values, (insertErr) => {
                if (insertErr) {
                  console.error(`❌ Failed to insert schedule ${index}:`, insertErr);
                } else {
                  insertedCount++;
                  console.log(`✅ Inserted schedule ${insertedCount}/${schedules.length}`);
                }

                if (index === schedules.length - 1) {
                  setTimeout(() => {
                    db.query(
                      `UPDATE timetable_uploads SET status = 'completed', processed_at = NOW(), entries_created = ? WHERE id = ?`,
                      [insertedCount, uploadId]
                    );

                    console.log(`✅ Successfully inserted ${insertedCount} schedules for upload ${uploadId}`);

                    res.status(201).json({
                      message: "Timetable uploaded and parsed successfully",
                      uploadId: uploadId,
                      totalClasses: insertedCount,
                      shift: parsedData.shift,
                      semester: parsedData.semester,
                      version: parsedData.version
                    });
                  }, 500);
                }
              });
            });
          });

        } catch (parseErr) {
          console.error("❌ PDF Parsing Error:", parseErr);
          db.query(
            `UPDATE timetable_uploads SET status = 'failed', error_message = ? WHERE id = ?`,
            [parseErr.message, uploadId]
          );

          res.status(500).json({
            message: "Failed to parse PDF",
            error: parseErr.message
          });
        }
      }
    );

  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

console.log("✅ Timetable upload endpoint initialized");

// ================= READ/PREVIEW PDF ENDPOINT (NEW) =================
app.post("/read-timetable-pdf", async (req, res) => {
  const { pdfBase64 } = req.body;

  if (!pdfBase64) {
    return res.status(400).json({ message: "PDF data is required" });
  }

  try {
    console.log('📖 Reading PDF for preview...');
    
    const pdfBuffer = Buffer.from(pdfBase64, 'base64');
    const pdfData = await pdfParse(pdfBuffer);
    const text = pdfData.text;
    
    // Extract metadata
    const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);
    
    // Detect shift
    let shift = 'Morning';
    const lowerText = text.toLowerCase();
    if (lowerText.includes('evening') || lowerText.includes('after/even')) {
      shift = 'Evening';
    }
    
    // Find all sections
    const sections = [];
    const sectionRegex = /^([A-Z]{2,4})-(\d+)([A-Z])$/;
    
    for (const line of lines) {
      const match = line.match(sectionRegex);
      if (match) {
        const [, degree, semester, section] = match;
        if (!sections.find(s => s.code === line)) {
          sections.push({
            code: line,
            degree: degree,
            semester: semester,
            section: section
          });
        }
      }
    }
    
    // Extract semester info
    const semesterMatch = text.match(/(Spring|Fall|Summer)[-\s]*\d{4}/i);
    const semester = semesterMatch ? semesterMatch[0].replace(/\s+/g, '-') : null;
    
    // Extract version
    const versionMatch = text.match(/Ver\s*[\d.]+/i);
    const version = versionMatch ? versionMatch[0] : null;
    
    res.status(200).json({
      message: "PDF read successfully",
      preview: {
        totalLines: lines.length,
        shift: shift,
        semester: semester,
        version: version,
        availableSections: sections,
        rawTextPreview: lines.slice(0, 50).join('\n') // First 50 lines
      }
    });
    
  } catch (error) {
    console.error("❌ PDF Reading Error:", error);
    res.status(500).json({ 
      message: "Failed to read PDF", 
      error: error.message 
    });
  }
});


//---------------------------enrollment endpoints
// ============================================================================
// 📍 GET AVAILABLE COURSES WITH SUBJECT-SPECIFIC TEACHERS
// ============================================================================
app.post("/get-courses-for-self-enrollment", (req, res) => {
  const { student_id, degree, section, semester_no } = req.body;

  console.log('📚 Fetching courses for self-enrollment:');
  console.log(`   Student ID: ${student_id}`);
  console.log(`   Class: ${degree}-${section}, Semester: ${semester_no}`);

  if (!student_id || !degree || !section || !semester_no) {
    return res.status(400).json({ 
      success: false,
      message: "All fields are required" 
    });
  }

  // Step 1: Get all unique subjects from student's timetable
  const subjectsSql = `
    SELECT DISTINCT
      subject_name,
      class_code
    FROM class_schedules
    WHERE degree = ? 
      AND section = ? 
      AND semester_no = ?
      AND is_active = 1
    ORDER BY subject_name
  `;

  db.query(subjectsSql, [degree, section, semester_no], (subjErr, subjects) => {
    if (subjErr) {
      console.error("❌ Database Error:", subjErr);
      return res.status(500).json({ 
        success: false,
        message: "Database error", 
        error: subjErr.message 
      });
    }

    console.log(`📊 Found ${subjects.length} subjects in timetable`);

    if (subjects.length === 0) {
      return res.status(200).json({
        success: true,
        message: "No subjects found in timetable",
        courses: [],
        statistics: { total_subjects: 0, total_teachers: 0, student_enrollments: 0 }
      });
    }

    // Step 2: Get student's current enrollments
    const enrollmentsSql = `
      SELECT 
        subject_name,
        teacher_id,
        teacher_name,
        id as enrollment_id,
        enrollment_status
      FROM student_enrollments
      WHERE student_id = ? 
        AND is_active = 1
    `;

    db.query(enrollmentsSql, [student_id], (enrollErr, enrollments) => {
      if (enrollErr) {
        console.error("❌ Database Error:", enrollErr);
        return res.status(500).json({ 
          success: false,
          message: "Database error", 
          error: enrollErr.message 
        });
      }

      console.log(`📋 Student has ${enrollments.length} active enrollments`);

      // Create enrollment map
      const enrolledMap = new Map();
      enrollments.forEach(e => {
        enrolledMap.set(e.subject_name, {
          teacher_id: e.teacher_id,
          teacher_name: e.teacher_name,
          enrollment_id: e.enrollment_id,
          enrollment_status: e.enrollment_status
        });
      });

      // Step 3: Get schedule details for each subject
      const schedulesSql = `
        SELECT 
          subject_name,
          day_of_week,
          start_time,
          end_time,
          room_number,
          building
        FROM class_schedules
        WHERE degree = ? 
          AND section = ? 
          AND semester_no = ?
          AND is_active = 1
        ORDER BY subject_name, 
                 FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'),
                 start_time
      `;

      db.query(schedulesSql, [degree, section, semester_no], (schedErr, schedules) => {
        if (schedErr) {
          console.error("❌ Database Error:", schedErr);
          return res.status(500).json({ 
            success: false,
            message: "Database error", 
            error: schedErr.message 
          });
        }

        // Group schedules by subject
        const scheduleMap = new Map();
        schedules.forEach(s => {
          if (!scheduleMap.has(s.subject_name)) {
            scheduleMap.set(s.subject_name, []);
          }
          scheduleMap.get(s.subject_name).push({
            day_of_week: s.day_of_week,
            start_time: s.start_time,
            end_time: s.end_time,
            room_number: s.room_number,
            building: s.building
          });
        });

        // Step 4: For EACH subject, get teachers who actually teach it
        // This prevents semester 2 students enrolling with semester 8 teachers
        const coursePromises = subjects.map(subject => {
          return new Promise((resolve, reject) => {
            // Get teachers who teach THIS SPECIFIC SUBJECT
            // We look at ALL schedules (any semester/section) where this teacher teaches this subject
            const teachersForSubjectSql = `
              SELECT DISTINCT
                cs.teacher_id,
                cs.teacher_name,
                cs.teacher_email,
                tr.profile_image,
                COUNT(DISTINCT cs.semester_no) as semesters_teaching,
                GROUP_CONCAT(DISTINCT CONCAT(cs.degree, '-', cs.section, ' (Sem ', cs.semester_no, ')') SEPARATOR ', ') as teaching_classes
              FROM class_schedules cs
              LEFT JOIN teacher_registration tr ON cs.teacher_id = tr.id
              WHERE cs.subject_name = ?
                AND cs.teacher_id IS NOT NULL
                AND cs.teacher_name IS NOT NULL
                AND cs.is_active = 1
              GROUP BY cs.teacher_id, cs.teacher_name, cs.teacher_email, tr.profile_image
              ORDER BY cs.teacher_name
            `;

            db.query(teachersForSubjectSql, [subject.subject_name], (teachErr, teachers) => {
              if (teachErr) {
                console.error(`❌ Error fetching teachers for ${subject.subject_name}:`, teachErr);
                reject(teachErr);
                return;
              }

              console.log(`   📚 ${subject.subject_name}: ${teachers.length} teacher(s) found`);

              const enrollment = enrolledMap.get(subject.subject_name);
              const subjectSchedules = scheduleMap.get(subject.subject_name) || [];

              resolve({
                subject_name: subject.subject_name,
                class_code: subject.class_code,
                schedules: subjectSchedules,
                is_enrolled: !!enrollment,
                enrolled_teacher: enrollment ? {
                  teacher_id: enrollment.teacher_id,
                  teacher_name: enrollment.teacher_name,
                  enrollment_id: enrollment.enrollment_id,
                  enrollment_status: enrollment.enrollment_status
                } : null,
                available_teachers: teachers.map(t => ({
                  teacher_id: t.teacher_id,
                  teacher_name: t.teacher_name,
                  teacher_email: t.teacher_email,
                  profile_image: t.profile_image,
                  semesters_teaching: t.semesters_teaching,
                  teaching_classes: t.teaching_classes
                }))
              });
            });
          });
        });

        // Step 5: Wait for all subject queries to complete
        Promise.all(coursePromises)
          .then(courses => {
            const totalTeachers = courses.reduce((sum, c) => sum + c.available_teachers.length, 0);

            console.log(`✅ Prepared ${courses.length} courses for self-enrollment`);
            console.log(`   Total teacher-subject combinations: ${totalTeachers}`);

            res.status(200).json({
              success: true,
              message: "Courses fetched successfully",
              courses: courses,
              statistics: {
                total_subjects: subjects.length,
                total_teachers: totalTeachers,
                student_enrollments: enrollments.length
              }
            });
          })
          .catch(error => {
            console.error("❌ Error processing courses:", error);
            res.status(500).json({ 
              success: false,
              message: "Error processing courses", 
              error: error.message 
            });
          });
      });
    });
  });
});

// ============================================================================
// 📍 ENDPOINT 1: GET AVAILABLE COURSES WITH SUBJECT-SPECIFIC TEACHERS
// ============================================================================
app.post("/get-courses-for-self-enrollment", (req, res) => {
  const { student_id, degree, section, semester_no } = req.body;

  console.log('📚 Fetching courses for self-enrollment:');
  console.log(`   Student ID: ${student_id}`);
  console.log(`   Class: ${degree}-${section}, Semester: ${semester_no}`);

  if (!student_id || !degree || !section || !semester_no) {
    return res.status(400).json({ 
      success: false,
      message: "All fields are required" 
    });
  }

  // Step 1: Get all unique subjects from student's timetable
  const subjectsSql = `
    SELECT DISTINCT
      subject_name,
      class_code
    FROM class_schedules
    WHERE degree = ? 
      AND section = ? 
      AND semester_no = ?
      AND is_active = 1
    ORDER BY subject_name
  `;

  db.query(subjectsSql, [degree, section, semester_no], (subjErr, subjects) => {
    if (subjErr) {
      console.error("❌ Database Error:", subjErr);
      return res.status(500).json({ 
        success: false,
        message: "Database error", 
        error: subjErr.message 
      });
    }

    console.log(`📊 Found ${subjects.length} subjects in timetable`);

    if (subjects.length === 0) {
      return res.status(200).json({
        success: true,
        message: "No subjects found in timetable",
        courses: [],
        statistics: { total_subjects: 0, total_teachers: 0, student_enrollments: 0 }
      });
    }

    // Step 2: Get student's current enrollments
    const enrollmentsSql = `
      SELECT 
        subject_name,
        teacher_id,
        teacher_name,
        id as enrollment_id,
        enrollment_status
      FROM student_enrollments
      WHERE student_id = ? 
        AND is_active = 1
    `;

    db.query(enrollmentsSql, [student_id], (enrollErr, enrollments) => {
      if (enrollErr) {
        console.error("❌ Database Error:", enrollErr);
        return res.status(500).json({ 
          success: false,
          message: "Database error", 
          error: enrollErr.message 
        });
      }

      console.log(`📋 Student has ${enrollments.length} active enrollments`);

      // Create enrollment map
      const enrolledMap = new Map();
      enrollments.forEach(e => {
        enrolledMap.set(e.subject_name, {
          teacher_id: e.teacher_id,
          teacher_name: e.teacher_name,
          enrollment_id: e.enrollment_id,
          enrollment_status: e.enrollment_status
        });
      });

      // Step 3: Get schedule details for each subject
      const schedulesSql = `
        SELECT 
          subject_name,
          day_of_week,
          start_time,
          end_time,
          room_number,
          building
        FROM class_schedules
        WHERE degree = ? 
          AND section = ? 
          AND semester_no = ?
          AND is_active = 1
        ORDER BY subject_name, 
                 FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'),
                 start_time
      `;

      db.query(schedulesSql, [degree, section, semester_no], (schedErr, schedules) => {
        if (schedErr) {
          console.error("❌ Database Error:", schedErr);
          return res.status(500).json({ 
            success: false,
            message: "Database error", 
            error: schedErr.message 
          });
        }

        // Group schedules by subject
        const scheduleMap = new Map();
        schedules.forEach(s => {
          if (!scheduleMap.has(s.subject_name)) {
            scheduleMap.set(s.subject_name, []);
          }
          scheduleMap.get(s.subject_name).push({
            day_of_week: s.day_of_week,
            start_time: s.start_time,
            end_time: s.end_time,
            room_number: s.room_number,
            building: s.building
          });
        });

        // Step 4: For EACH subject, get teachers who actually teach it
        const coursePromises = subjects.map(subject => {
          return new Promise((resolve, reject) => {
            // Get teachers who teach THIS SPECIFIC SUBJECT
            const teachersForSubjectSql = `
              SELECT DISTINCT
                cs.teacher_id,
                cs.teacher_name,
                cs.teacher_email,
                tr.profile_image,
                COUNT(DISTINCT cs.semester_no) as semesters_teaching,
                GROUP_CONCAT(DISTINCT CONCAT(cs.degree, '-', cs.section, ' (Sem ', cs.semester_no, ')') SEPARATOR ', ') as teaching_classes
              FROM class_schedules cs
              LEFT JOIN teacher_registration tr ON cs.teacher_id = tr.id
              WHERE cs.subject_name = ?
                AND cs.teacher_id IS NOT NULL
                AND cs.teacher_name IS NOT NULL
                AND cs.is_active = 1
              GROUP BY cs.teacher_id, cs.teacher_name, cs.teacher_email, tr.profile_image
              ORDER BY cs.teacher_name
            `;

            db.query(teachersForSubjectSql, [subject.subject_name], (teachErr, teachers) => {
              if (teachErr) {
                console.error(`❌ Error fetching teachers for ${subject.subject_name}:`, teachErr);
                reject(teachErr);
                return;
              }

              console.log(`   📚 ${subject.subject_name}: ${teachers.length} teacher(s) found`);

              const enrollment = enrolledMap.get(subject.subject_name);
              const subjectSchedules = scheduleMap.get(subject.subject_name) || [];

              resolve({
                subject_name: subject.subject_name,
                class_code: subject.class_code,
                schedules: subjectSchedules,
                is_enrolled: !!enrollment,
                enrolled_teacher: enrollment ? {
                  teacher_id: enrollment.teacher_id,
                  teacher_name: enrollment.teacher_name,
                  enrollment_id: enrollment.enrollment_id,
                  enrollment_status: enrollment.enrollment_status
                } : null,
                available_teachers: teachers.map(t => ({
                  teacher_id: t.teacher_id,
                  teacher_name: t.teacher_name,
                  teacher_email: t.teacher_email,
                  profile_image: t.profile_image,
                  semesters_teaching: t.semesters_teaching,
                  teaching_classes: t.teaching_classes
                }))
              });
            });
          });
        });

        // Step 5: Wait for all subject queries to complete
        Promise.all(coursePromises)
          .then(courses => {
            const totalTeachers = courses.reduce((sum, c) => sum + c.available_teachers.length, 0);

            console.log(`✅ Prepared ${courses.length} courses for self-enrollment`);
            console.log(`   Total teacher-subject combinations: ${totalTeachers}`);

            res.status(200).json({
              success: true,
              message: "Courses fetched successfully",
              courses: courses,
              statistics: {
                total_subjects: subjects.length,
                total_teachers: totalTeachers,
                student_enrollments: enrollments.length
              }
            });
          })
          .catch(error => {
            console.error("❌ Error processing courses:", error);
            res.status(500).json({ 
              success: false,
              message: "Error processing courses", 
              error: error.message 
            });
          });
      });
    });
  });
});

// ============================================================================
// 📍 ENDPOINT 2: SELF-ENROLL IN COURSE WITH VALIDATION & REACTIVATION
// ============================================================================
app.post("/self-enroll-in-course", (req, res) => {
  const {
    student_id,
    student_name,
    student_email,
    student_degree,
    student_section,
    student_semester_no,
    subject_name,
    class_code,
    teacher_id,
    teacher_name,
    teacher_email
  } = req.body;

  console.log('📝 Self-enrollment request:');
  console.log(`   Student: ${student_name} (ID: ${student_id})`);
  console.log(`   Subject: ${subject_name}`);
  console.log(`   Teacher: ${teacher_name} (ID: ${teacher_id})`);
  console.log(`   Class: ${student_degree}-${student_section}, Semester: ${student_semester_no}`);

  // Validation
  if (!student_id || !student_name || !student_email || 
      !student_degree || !student_section || !student_semester_no ||
      !subject_name || !teacher_id || !teacher_name) {
    return res.status(400).json({ 
      success: false,
      message: "All fields are required" 
    });
  }

  // Step 1: Verify teacher actually teaches this subject TO THIS SPECIFIC CLASS
  const verifyTeacherSql = `
    SELECT COUNT(*) as teaches_count
    FROM class_schedules
    WHERE subject_name = ?
      AND teacher_id = ?
      AND degree = ?
      AND section = ?
      AND semester_no = ?
      AND is_active = 1
    LIMIT 1
  `;

  db.query(verifyTeacherSql, [subject_name, teacher_id, student_degree, student_section, student_semester_no], (verifyErr, verifyResults) => {
    if (verifyErr) {
      console.error("❌ Database Error:", verifyErr);
      return res.status(500).json({ 
        success: false,
        message: "Database error during verification", 
        error: verifyErr.message 
      });
    }

    if (verifyResults[0].teaches_count === 0) {
      console.log(`⚠️ VALIDATION FAILED: Teacher ${teacher_name} does not teach ${subject_name} to ${student_degree}-${student_section} Semester ${student_semester_no}`);
      return res.status(400).json({ 
        success: false,
        message: `Cannot enroll: ${teacher_name} does not teach ${subject_name} to your class (${student_degree}-${student_section}, Semester ${student_semester_no}). Please select a teacher who teaches this subject to your class.`
      });
    }

    console.log(`✅ Validation passed: Teacher teaches this subject to this class`);

    // Step 2: Get schedule_id for this subject and student's class
    const getScheduleSql = `
      SELECT id as schedule_id
      FROM class_schedules
      WHERE subject_name = ?
        AND degree = ?
        AND section = ?
        AND semester_no = ?
        AND is_active = 1
      LIMIT 1
    `;

    db.query(getScheduleSql, [subject_name, student_degree, student_section, student_semester_no], 
      (getSchedErr, getSchedResults) => {
        if (getSchedErr || getSchedResults.length === 0) {
          console.error("❌ Schedule not found for subject:", subject_name);
          return res.status(404).json({ 
            success: false,
            message: "Schedule not found for this subject in your class" 
          });
        }

        const schedule_id = getSchedResults[0].schedule_id;
        console.log(`📋 Found schedule_id: ${schedule_id}`);

        // Step 3: Check for existing enrollment (ACTIVE OR INACTIVE)
        const checkAllSql = `
          SELECT 
            id, 
            teacher_name, 
            teacher_id,
            enrollment_status,
            is_active
          FROM student_enrollments
          WHERE student_id = ? 
            AND (subject_name = ? OR schedule_id = ?)
          ORDER BY is_active DESC
          LIMIT 1
        `;

        db.query(checkAllSql, [student_id, subject_name, schedule_id], (checkErr, checkResults) => {
          if (checkErr) {
            console.error("❌ Database Error:", checkErr);
            return res.status(500).json({ 
              success: false,
              message: "Database error", 
              error: checkErr.message 
            });
          }

          // Case 1: Active enrollment exists
          if (checkResults.length > 0 && checkResults[0].is_active === 1) {
            const existing = checkResults[0];
            console.log("⚠️ Student already enrolled (active)");
            return res.status(400).json({ 
              success: false,
              message: `You are already enrolled in "${subject_name}" with ${existing.teacher_name}. Please unenroll first if you want to switch teachers.`,
              existing_enrollment: {
                teacher_name: existing.teacher_name,
                enrollment_id: existing.id,
                enrollment_status: existing.enrollment_status
              }
            });
          }

          // Case 2: Inactive enrollment exists - REACTIVATE IT
          if (checkResults.length > 0 && checkResults[0].is_active === 0) {
            const existing = checkResults[0];
            console.log(`🔄 Found inactive enrollment (ID: ${existing.id}), reactivating...`);

            const reactivateSql = `
              UPDATE student_enrollments
              SET 
                is_active = 1,
                teacher_id = ?,
                teacher_name = ?,
                teacher_email = ?,
                enrollment_status = 'approved'
              WHERE id = ?
            `;

            db.query(reactivateSql, [teacher_id, teacher_name, teacher_email || '', existing.id], 
              (reactivateErr, reactivateResult) => {
                if (reactivateErr) {
                  console.error("❌ Reactivation Error:", reactivateErr);
                  return res.status(500).json({ 
                    success: false,
                    message: "Failed to reactivate enrollment", 
                    error: reactivateErr.message 
                  });
                }

                console.log(`✅ ENROLLMENT REACTIVATED!`);
                console.log(`   Enrollment ID: ${existing.id}`);
                console.log(`   ${student_name} re-enrolled in ${subject_name} with ${teacher_name}`);

                // Update schedule with teacher info
                const updateScheduleSql = `
                  UPDATE class_schedules
                  SET teacher_id = ?,
                      teacher_name = ?,
                      teacher_email = ?
                  WHERE subject_name = ?
                    AND degree = ?
                    AND section = ?
                    AND semester_no = ?
                    AND is_active = 1
                    AND (teacher_id IS NULL OR teacher_id = ?)
                `;

                db.query(updateScheduleSql, 
                  [teacher_id, teacher_name, teacher_email, subject_name, student_degree, student_section, student_semester_no, teacher_id],
                  (updateErr) => {
                    if (updateErr) {
                      console.log("⚠️ Note: Could not update schedule:", updateErr.message);
                    } else {
                      console.log(`✅ Updated schedule with teacher info`);
                    }
                  }
                );

                res.status(201).json({
                  success: true,
                  message: `Successfully enrolled in ${subject_name}`,
                  enrollment: {
                    enrollment_id: existing.id,
                    subject_name: subject_name,
                    class_code: class_code,
                    teacher_name: teacher_name,
                    teacher_id: teacher_id,
                    enrollment_status: 'approved',
                    enrolled_at: new Date(),
                    was_reactivated: true
                  }
                });
              }
            );
            return;
          }

          // Case 3: No enrollment exists - CREATE NEW
          console.log('📝 No existing enrollment found, creating new...');

          const insertSql = `
            INSERT INTO student_enrollments
            (student_id, student_name, student_email, student_degree, student_section, student_semester_no,
             teacher_id, teacher_name, teacher_email, schedule_id, subject_name, class_code, enrollment_status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'approved')
          `;

          const insertValues = [
            student_id, 
            student_name, 
            student_email, 
            student_degree, 
            student_section, 
            student_semester_no,
            teacher_id,
            teacher_name, 
            teacher_email || '',
            schedule_id, 
            subject_name, 
            class_code || ''
          ];

          db.query(insertSql, insertValues, (insertErr, insertResult) => {
            if (insertErr) {
              console.error("❌ Insert Error:", insertErr);
              
              // This shouldn't happen now, but just in case
              if (insertErr.code === 'ER_DUP_ENTRY') {
                return res.status(400).json({ 
                  success: false,
                  message: "Enrollment record conflict. Please refresh and try again."
                });
              }
              
              return res.status(500).json({ 
                success: false,
                message: "Failed to create enrollment", 
                error: insertErr.message 
              });
            }

            console.log(`✅ NEW ENROLLMENT CREATED!`);
            console.log(`   Enrollment ID: ${insertResult.insertId}`);
            console.log(`   ${student_name} enrolled in ${subject_name} with ${teacher_name}`);

            // Update schedule with teacher info
            const updateScheduleSql = `
              UPDATE class_schedules
              SET teacher_id = ?,
                  teacher_name = ?,
                  teacher_email = ?
              WHERE subject_name = ?
                AND degree = ?
                AND section = ?
                AND semester_no = ?
                AND is_active = 1
                AND (teacher_id IS NULL OR teacher_id = ?)
            `;

            db.query(updateScheduleSql, 
              [teacher_id, teacher_name, teacher_email, subject_name, student_degree, student_section, student_semester_no, teacher_id],
              (updateErr) => {
                if (updateErr) {
                  console.log("⚠️ Note: Could not update schedule:", updateErr.message);
                } else {
                  console.log(`✅ Updated schedule with teacher info`);
                }
              }
            );

            res.status(201).json({
              success: true,
              message: `Successfully enrolled in ${subject_name}`,
              enrollment: {
                enrollment_id: insertResult.insertId,
                subject_name: subject_name,
                class_code: class_code,
                teacher_name: teacher_name,
                teacher_id: teacher_id,
                enrollment_status: 'approved',
                enrolled_at: new Date(),
                was_reactivated: false
              }
            });
          });
        });
      }
    );
  });
});

// ============================================================================
// 📍 ENDPOINT 3: GET ENROLLED COURSES
// ============================================================================
app.post("/get-self-enrolled-courses", (req, res) => {
  const { student_id } = req.body;

  console.log('📋 Fetching self-enrolled courses for student:', student_id);

  if (!student_id) {
    return res.status(400).json({ 
      success: false,
      message: "Student ID is required" 
    });
  }

  const sql = `
    SELECT 
      se.id,
      se.student_id,
      se.subject_name,
      se.class_code,
      se.teacher_id,
      se.teacher_name,
      se.teacher_email,
      se.enrollment_status,
      se.enrolled_at,
      se.student_degree,
      se.student_section,
      se.student_semester_no,
      se.schedule_id,
      tr.profile_image as teacher_profile_image
    FROM student_enrollments se
    LEFT JOIN teacher_registration tr ON se.teacher_id = tr.id
    WHERE se.student_id = ? 
      AND se.is_active = 1
    ORDER BY se.subject_name
  `;

  db.query(sql, [student_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ 
        success: false,
        message: "Failed to fetch enrollments", 
        error: err.message 
      });
    }

    if (results.length === 0) {
      return res.status(200).json({
        success: true,
        message: "No enrollments found",
        enrollments: [],
        totalEnrollments: 0
      });
    }

    const schedulesSql = `
      SELECT 
        subject_name,
        day_of_week,
        start_time,
        end_time,
        room_number,
        building
      FROM class_schedules
      WHERE degree = ?
        AND section = ?
        AND semester_no = ?
        AND is_active = 1
      ORDER BY subject_name,
               FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'),
               start_time
    `;

    const firstResult = results[0];
    db.query(schedulesSql, [firstResult.student_degree, firstResult.student_section, firstResult.student_semester_no],
      (schedErr, schedules) => {
        if (schedErr) {
          console.error("⚠️ Could not fetch schedules:", schedErr);
          return res.status(200).json({
            success: true,
            message: "Enrollments fetched successfully",
            enrollments: results,
            totalEnrollments: results.length
          });
        }

        const scheduleMap = new Map();
        schedules.forEach(s => {
          if (!scheduleMap.has(s.subject_name)) {
            scheduleMap.set(s.subject_name, []);
          }
          scheduleMap.get(s.subject_name).push({
            day_of_week: s.day_of_week,
            start_time: s.start_time,
            end_time: s.end_time,
            room_number: s.room_number,
            building: s.building
          });
        });

        const enrichedResults = results.map(enrollment => ({
          ...enrollment,
          schedules: scheduleMap.get(enrollment.subject_name) || []
        }));

        console.log(`✅ Found ${enrichedResults.length} enrollments for student ${student_id}`);

        res.status(200).json({
          success: true,
          message: "Enrollments fetched successfully",
          enrollments: enrichedResults,
          totalEnrollments: enrichedResults.length
        });
      }
    );
  });
});

// ============================================================================
// 📍 ENDPOINT 4: UNENROLL FROM COURSE (Keep your existing one)
// ============================================================================
app.post("/unenroll-from-course", (req, res) => {
  const { student_id, enrollment_id } = req.body;

  console.log('🗑️ Unenrollment request:');
  console.log(`   Student ID: ${student_id}`);
  console.log(`   Enrollment ID: ${enrollment_id}`);

  if (!student_id || !enrollment_id) {
    return res.status(400).json({ 
      success: false,
      message: "Student ID and Enrollment ID are required" 
    });
  }

  // Get enrollment details first
  const getEnrollmentSql = `
    SELECT subject_name, teacher_name 
    FROM student_enrollments 
    WHERE id = ? AND student_id = ? AND is_active = 1
  `;

  db.query(getEnrollmentSql, [enrollment_id, student_id], (getErr, getResults) => {
    if (getErr) {
      console.error("❌ Database Error:", getErr);
      return res.status(500).json({ 
        success: false,
        message: "Failed to unenroll", 
        error: getErr.message 
      });
    }

    if (getResults.length === 0) {
      console.log("⚠️ Enrollment not found or already inactive");
      return res.status(404).json({ 
        success: false,
        message: "Enrollment not found or already inactive" 
      });
    }

    const enrollment = getResults[0];

    // Soft delete
    const updateSql = `
      UPDATE student_enrollments 
      SET is_active = 0
      WHERE id = ? 
        AND student_id = ?
        AND is_active = 1
    `;

    db.query(updateSql, [enrollment_id, student_id], (updateErr, updateResult) => {
      if (updateErr) {
        console.error("❌ Database Error:", updateErr);
        return res.status(500).json({ 
          success: false,
          message: "Failed to unenroll", 
          error: updateErr.message 
        });
      }

      if (updateResult.affectedRows === 0) {
        console.log("⚠️ No rows affected");
        return res.status(404).json({ 
          success: false,
          message: "Enrollment not found or already inactive" 
        });
      }

      console.log(`✅ Student ${student_id} unenrolled from enrollment ${enrollment_id}`);
      console.log(`   Subject: ${enrollment.subject_name}`);
      console.log(`   Teacher: ${enrollment.teacher_name}`);

      res.status(200).json({
        success: true,
        message: "Successfully unenrolled from course",
        unenrolled_course: {
          subject_name: enrollment.subject_name,
          teacher_name: enrollment.teacher_name
        }
      });
    });
  });
});

// ================= ATTENDANCE ENDPOINTS =================

// 📍 GET STUDENT ATTENDANCE (for specific schedule)
app.post("/get-student-attendance", (req, res) => {
  const { student_id, schedule_id } = req.body;

  console.log('📊 Fetching attendance for student:', student_id, 'schedule:', schedule_id);

  if (!student_id || !schedule_id) {
    return res.status(400).json({ message: "Student ID and Schedule ID required" });
  }

  // Get attendance records
  const recordsSql = `
    SELECT 
      date,
      time,
      status
    FROM attendance_records
    WHERE student_id = ? AND schedule_id = ?
    ORDER BY date DESC, time DESC
  `;

  db.query(recordsSql, [student_id, schedule_id], (err, records) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch attendance", error: err });
    }

    // Calculate statistics
    const totalClasses = records.length;
    const attendedClasses = records.filter(r => r.status === 'present').length;
    const percentage = totalClasses > 0 ? ((attendedClasses / totalClasses) * 100).toFixed(2) : 0;

    console.log(`✅ Student ${student_id}: ${attendedClasses}/${totalClasses} (${percentage}%)`);

    res.status(200).json({
      message: "Attendance fetched successfully",
      totalClasses,
      attendedClasses,
      percentage: parseFloat(percentage),
      records
    });
  });
});

// 📍 MARK SELF ATTENDANCE (Student marks own attendance)
app.post("/mark-self-attendance", (req, res) => {
  const { student_id, schedule_id, student_name } = req.body;

  console.log('✍️ Self-attendance request:', { student_id, schedule_id, student_name });

  if (!student_id || !schedule_id || !student_name) {
    return res.status(400).json({ message: "All fields required" });
  }

  const today = new Date().toISOString().split('T')[0];
  const now = new Date().toTimeString().split(' ')[0];

  // Check if already marked today
  const checkSql = `
    SELECT id FROM attendance_records
    WHERE student_id = ? AND schedule_id = ? AND date = ?
    LIMIT 1
  `;

  db.query(checkSql, [student_id, schedule_id, today], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Check Error:", checkErr);
      return res.status(500).json({ message: "Database error", error: checkErr });
    }

    if (checkResults.length > 0) {
      return res.status(400).json({ 
        message: "Attendance already marked for today" 
      });
    }

    // Mark attendance
    const insertSql = `
      INSERT INTO attendance_records
      (student_id, student_name, schedule_id, date, time, status, marked_by)
      VALUES (?, ?, ?, ?, ?, 'present', 'student')
    `;

    db.query(
      insertSql,
      [student_id, student_name, schedule_id, today, now],
      (insertErr, result) => {
        if (insertErr) {
          console.error("❌ Insert Error:", insertErr);
          return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
        }

        console.log(`✅ Self-attendance marked for student ${student_id}`);

        res.status(201).json({
          message: "Attendance marked successfully",
          attendance_id: result.insertId
        });
      }
    );
  });
});

// 📍 GET CLASS STATISTICS (for teacher dashboard)
app.post("/get-class-statistics", (req, res) => {
  const { schedule_id } = req.body;

  if (!schedule_id) {
    return res.status(400).json({ message: "Schedule ID required" });
  }

  // Get unique dates (classes taken)
  const classesSql = `
    SELECT COUNT(DISTINCT date) as total_classes
    FROM attendance_records
    WHERE schedule_id = ?
  `;

  // Get enrolled students count
  const studentsSql = `
    SELECT COUNT(*) as total_students
    FROM student_enrollments
    WHERE schedule_id = ? AND is_active = 1
  `;

  // Get average attendance
  const attendanceSql = `
    SELECT 
      COUNT(CASE WHEN status = 'present' THEN 1 END) as present_count,
      COUNT(*) as total_records
    FROM attendance_records
    WHERE schedule_id = ?
  `;

  db.query(classesSql, [schedule_id], (err1, classResults) => {
    if (err1) {
      console.error("❌ Error:", err1);
      return res.status(500).json({ message: "Database error" });
    }

    db.query(studentsSql, [schedule_id], (err2, studentResults) => {
      if (err2) {
        console.error("❌ Error:", err2);
        return res.status(500).json({ message: "Database error" });
      }

      db.query(attendanceSql, [schedule_id], (err3, attendanceResults) => {
        if (err3) {
          console.error("❌ Error:", err3);
          return res.status(500).json({ message: "Database error" });
        }

        const totalClasses = classResults[0].total_classes || 0;
        const totalStudents = studentResults[0].total_students || 0;
        const presentCount = attendanceResults[0].present_count || 0;
        const totalRecords = attendanceResults[0].total_records || 0;
        const averageAttendance = totalRecords > 0 
          ? ((presentCount / totalRecords) * 100).toFixed(2) 
          : 0;

        res.status(200).json({
          message: "Statistics fetched successfully",
          totalClassesTaken: totalClasses,
          totalStudents,
          averageAttendance: parseFloat(averageAttendance)
        });
      });
    });
  });
});

// 📍 MARK CLASS ATTENDANCE (Teacher marks attendance for entire class)
app.post("/mark-class-attendance", (req, res) => {
  const { teacher_id, schedule_id, attendance, date } = req.body;

  console.log('📝 Class attendance marking:');
  console.log(`   Teacher: ${teacher_id}, Schedule: ${schedule_id}`);
  console.log(`   Date: ${date}, Students: ${attendance.length}`);

  if (!teacher_id || !schedule_id || !attendance || !date) {
    return res.status(400).json({ message: "All fields required" });
  }

  const now = new Date().toTimeString().split(' ')[0];

  // Check if attendance already marked for this date
  const checkSql = `
    SELECT id FROM attendance_records
    WHERE schedule_id = ? AND date = ?
    LIMIT 1
  `;

  db.query(checkSql, [schedule_id, date], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Check Error:", checkErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (checkResults.length > 0) {
      return res.status(400).json({ 
        message: "Attendance already marked for this date. Please edit existing records." 
      });
    }

    // Insert attendance records
    const insertSql = `
      INSERT INTO attendance_records
      (student_id, student_name, schedule_id, date, time, status, marked_by, teacher_id)
      VALUES ?
    `;

    const values = attendance.map(record => [
      record.student_id,
      record.student_name,
      schedule_id,
      date,
      now,
      record.status,
      'teacher',
      teacher_id
    ]);

    db.query(insertSql, [values], (insertErr, result) => {
      if (insertErr) {
        console.error("❌ Insert Error:", insertErr);
        return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
      }

      const presentCount = attendance.filter(r => r.status === 'present').length;
      const absentCount = attendance.length - presentCount;

      console.log(`✅ Attendance marked: ${presentCount} present, ${absentCount} absent`);

      res.status(201).json({
        message: `Attendance marked successfully for ${attendance.length} students`,
        presentCount,
        absentCount,
        totalRecords: result.affectedRows
      });
    });
  });
});

// 📍 UPDATE ATTENDANCE RECORD (Edit existing attendance)
app.post("/update-attendance-record", (req, res) => {
  const { record_id, status, teacher_id } = req.body;

  if (!record_id || !status || !teacher_id) {
    return res.status(400).json({ message: "All fields required" });
  }

  const updateSql = `
    UPDATE attendance_records
    SET status = ?, updated_at = NOW()
    WHERE id = ? AND teacher_id = ?
  `;

  db.query(updateSql, [status, record_id, teacher_id], (err, result) => {
    if (err) {
      console.error("❌ Update Error:", err);
      return res.status(500).json({ message: "Failed to update", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Record not found" });
    }

    console.log(`✅ Attendance record ${record_id} updated to ${status}`);

    res.status(200).json({
      message: "Attendance updated successfully"
    });
  });
});

// 📍 GET ATTENDANCE HISTORY (for detailed view)
app.post("/get-attendance-history", (req, res) => {
  const { schedule_id, start_date, end_date } = req.body;

  if (!schedule_id) {
    return res.status(400).json({ message: "Schedule ID required" });
  }

  let sql = `
    SELECT 
      ar.*,
      se.student_email,
      se.student_section
    FROM attendance_records ar
    LEFT JOIN student_enrollments se ON 
      ar.student_id = se.student_id AND ar.schedule_id = se.schedule_id
    WHERE ar.schedule_id = ?
  `;

  const params = [schedule_id];

  if (start_date && end_date) {
    sql += ` AND ar.date BETWEEN ? AND ?`;
    params.push(start_date, end_date);
  }

  sql += ` ORDER BY ar.date DESC, ar.student_name`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Error:", err);
      return res.status(500).json({ message: "Failed to fetch history", error: err });
    }

    // Group by date
    const groupedByDate = {};
    results.forEach(record => {
      const date = record.date;
      if (!groupedByDate[date]) {
        groupedByDate[date] = [];
      }
      groupedByDate[date].push(record);
    });

    res.status(200).json({
      message: "History fetched successfully",
      records: results,
      groupedByDate,
      totalRecords: results.length
    });
  });
});

console.log("✅ Attendance endpoints initialized");


// ================= STUDENT ENROLLMENT ENDPOINTS =================

// 📍 GET AVAILABLE COURSES FOR ENROLLMENT (Student View)
app.post("/get-available-courses-for-enrollment", (req, res) => {
  const { student_id, degree, section, semester_no } = req.body;

  console.log('📚 Fetching available courses for enrollment:');
  console.log(`   Student ID: ${student_id}`);
  console.log(`   Degree: ${degree}, Section: ${section}, Semester: ${semester_no}`);

  if (!student_id || !degree || !section || !semester_no) {
    return res.status(400).json({ message: "All fields are required" });
  }

  // Get all courses for this section/semester with enrollment status
  const sql = `
    SELECT 
      cs.id as schedule_id,
      cs.subject_name,
      cs.class_code,
      cs.day_of_week,
      cs.start_time,
      cs.end_time,
      cs.room_number,
      cs.building,
      cs.teacher_id,
      cs.teacher_name,
      cs.teacher_email,
      cs.degree,
      cs.section,
      cs.semester_no,
      se.id as enrollment_id,
      se.enrollment_status,
      se.enrolled_at,
      CASE 
        WHEN se.id IS NOT NULL THEN 1
        ELSE 0
      END as is_enrolled
    FROM class_schedules cs
    LEFT JOIN student_enrollments se ON 
      cs.id = se.schedule_id 
      AND se.student_id = ?
      AND se.is_active = 1
    WHERE cs.degree = ? 
      AND cs.section = ? 
      AND cs.semester_no = ?
      AND cs.is_active = 1
    ORDER BY cs.subject_name, cs.teacher_name
  `;

  db.query(sql, [student_id, degree, section, semester_no], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch courses", error: err });
    }

    // Group by subject to show different teachers for same subject
    const courseMap = {};
    results.forEach(row => {
      const key = row.subject_name;
      if (!courseMap[key]) {
        courseMap[key] = {
          subject_name: row.subject_name,
          class_code: row.class_code,
          teachers: []
        };
      }

      courseMap[key].teachers.push({
        schedule_id: row.schedule_id,
        teacher_id: row.teacher_id,
        teacher_name: row.teacher_name,
        teacher_email: row.teacher_email,
        day_of_week: row.day_of_week,
        start_time: row.start_time,
        end_time: row.end_time,
        room_number: row.room_number,
        building: row.building,
        is_enrolled: row.is_enrolled === 1,
        enrollment_id: row.enrollment_id,
        enrollment_status: row.enrollment_status,
        enrolled_at: row.enrolled_at
      });
    });

    const courses = Object.values(courseMap);

    console.log(`✅ Found ${courses.length} courses with ${results.length} total sections`);

    res.status(200).json({
      message: "Courses fetched successfully",
      courses: courses,
      totalCourses: courses.length,
      totalSections: results.length
    });
  });
});

// 📍 ENROLL IN COURSE (Student enrolls for a specific teacher's section)
app.post("/enroll-in-course", async (req, res) => {
  const {
    student_id,
    student_name,
    student_email,
    student_degree,
    student_section,
    student_semester_no,
    schedule_id
  } = req.body;

  console.log('📝 Enrollment request:');
  console.log(`   Student: ${student_name} (ID: ${student_id})`);
  console.log(`   Schedule ID: ${schedule_id}`);

  if (!student_id || !student_name || !student_email || !schedule_id ||
      !student_degree || !student_section || !student_semester_no) {
    return res.status(400).json({ message: "All fields are required" });
  }

  try {
    // First, get the schedule details with teacher info
    const scheduleSql = `
      SELECT 
        cs.id, 
        cs.subject_name, 
        cs.class_code, 
        cs.teacher_id, 
        cs.teacher_name, 
        cs.teacher_email,
        cs.degree, 
        cs.section, 
        cs.semester_no
      FROM class_schedules cs
      WHERE cs.id = ? AND cs.is_active = 1
      LIMIT 1
    `;

    db.query(scheduleSql, [schedule_id], (scheduleErr, scheduleResults) => {
      if (scheduleErr) {
        console.error("❌ Database Error:", scheduleErr);
        return res.status(500).json({ message: "Database error", error: scheduleErr });
      }

      if (scheduleResults.length === 0) {
        console.error("❌ Schedule not found:", schedule_id);
        return res.status(404).json({ message: "Schedule not found" });
      }

      const schedule = scheduleResults[0];

      // ✅ CRITICAL FIX: Check if teacher_id exists
      if (!schedule.teacher_id || schedule.teacher_id === null) {
        console.error("❌ Schedule missing teacher_id:", schedule);
        return res.status(400).json({ 
          message: "This schedule is incomplete. Please contact administration.",
          error: "Missing teacher assignment"
        });
      }

      console.log('✅ Schedule found:', {
        id: schedule.id,
        subject: schedule.subject_name,
        teacher_id: schedule.teacher_id,
        teacher_name: schedule.teacher_name
      });

      // Check if already enrolled
      const checkSql = `
        SELECT id, enrollment_status 
        FROM student_enrollments 
        WHERE student_id = ? AND schedule_id = ? AND is_active = 1
        LIMIT 1
      `;

      db.query(checkSql, [student_id, schedule_id], (checkErr, checkResults) => {
        if (checkErr) {
          console.error("❌ Check Error:", checkErr);
          return res.status(500).json({ message: "Database error", error: checkErr });
        }

        if (checkResults.length > 0) {
          console.log("⚠️ Student already enrolled in this schedule");
          return res.status(400).json({ 
            message: "Already enrolled in this course",
            enrollment_status: checkResults[0].enrollment_status
          });
        }

        // Create enrollment with verified teacher_id
        const insertSql = `
          INSERT INTO student_enrollments
          (student_id, student_name, student_email, student_degree, student_section, student_semester_no,
           teacher_id, teacher_name, teacher_email, schedule_id, subject_name, class_code, enrollment_status)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'approved')
        `;

        const insertValues = [
          student_id, 
          student_name, 
          student_email, 
          student_degree, 
          student_section, 
          student_semester_no,
          schedule.teacher_id,  // ✅ This is now verified to be non-null
          schedule.teacher_name, 
          schedule.teacher_email,
          schedule_id, 
          schedule.subject_name, 
          schedule.class_code
        ];

        console.log('📋 Inserting enrollment with values:', {
          student_id,
          teacher_id: schedule.teacher_id,
          schedule_id,
          subject: schedule.subject_name
        });

        db.query(insertSql, insertValues, (insertErr, insertResult) => {
          if (insertErr) {
            console.error("❌ Insert Error:", insertErr);
            return res.status(500).json({ 
              message: "Failed to enroll", 
              error: insertErr.message 
            });
          }

          console.log(`✅ Student ${student_name} enrolled in ${schedule.subject_name} with ${schedule.teacher_name}`);
          console.log(`   Enrollment ID: ${insertResult.insertId}`);

          // Send email notification to student
          const studentMailOptions = {
            to: student_email,
            subject: `Enrollment Confirmation - ${schedule.subject_name}`,
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #667eea;">✅ Enrollment Confirmed!</h2>
                <p>Hi ${student_name},</p>
                <p>You have successfully enrolled in:</p>
                <div style="background: #f0f4ff; padding: 15px; border-radius: 8px; margin: 20px 0;">
                  <p><strong>Subject:</strong> ${schedule.subject_name}</p>
                  <p><strong>Class Code:</strong> ${schedule.class_code || 'N/A'}</p>
                  <p><strong>Teacher:</strong> ${schedule.teacher_name}</p>
                  <p><strong>Section:</strong> ${schedule.degree}-${schedule.section}</p>
                </div>
                <p>Your enrollment is now active. Attendance tracking will begin from the next class.</p>
              </div>
            `
          };

          mailTransporter.sendMail(studentMailOptions, (mailErr) => {
            if (mailErr) console.error("⚠️ Failed to send student email:", mailErr);
            else console.log("✅ Enrollment email sent to student");
          });

          // Send email notification to teacher
          if (schedule.teacher_email) {
            const teacherMailOptions = {
              to: schedule.teacher_email,
              subject: `New Student Enrollment - ${schedule.subject_name}`,
              html: `
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                  <h2 style="color: #667eea;">📚 New Student Enrolled</h2>
                  <p>Hi ${schedule.teacher_name},</p>
                  <p>A new student has enrolled in your class:</p>
                  <div style="background: #f0f4ff; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <p><strong>Student:</strong> ${student_name}</p>
                    <p><strong>Email:</strong> ${student_email}</p>
                    <p><strong>Subject:</strong> ${schedule.subject_name}</p>
                    <p><strong>Section:</strong> ${student_degree}-${student_section}</p>
                    <p><strong>Semester:</strong> ${student_semester_no}</p>
                  </div>
                </div>
              `
            };

            mailTransporter.sendMail(teacherMailOptions, (mailErr) => {
              if (mailErr) console.error("⚠️ Failed to send teacher email:", mailErr);
              else console.log("✅ Enrollment email sent to teacher");
            });
          }

          res.status(201).json({
            message: "Enrolled successfully",
            enrollment_id: insertResult.insertId,
            enrollment_status: 'approved'
          });
        });
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// 📍 UNENROLL FROM COURSE
app.post("/unenroll-from-course", (req, res) => {
  const { student_id, enrollment_id } = req.body;

  if (!student_id || !enrollment_id) {
    return res.status(400).json({ message: "Student ID and Enrollment ID are required" });
  }

  const sql = `
    UPDATE student_enrollments 
    SET is_active = 0
    WHERE id = ? AND student_id = ?
  `;

  db.query(sql, [enrollment_id, student_id], (err, result) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to unenroll", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Enrollment not found" });
    }

    console.log(`✅ Student ${student_id} unenrolled from enrollment ${enrollment_id}`);

    res.status(200).json({
      message: "Unenrolled successfully"
    });
  });
});

// 📍 GET ENROLLED COURSES (Student's enrolled courses)
app.post("/get-my-enrolled-courses", (req, res) => {
  const { student_id } = req.body;

  if (!student_id) {
    return res.status(400).json({ message: "Student ID is required" });
  }

  const sql = `
    SELECT 
      se.*,
      cs.day_of_week,
      cs.start_time,
      cs.end_time,
      cs.room_number,
      cs.building
    FROM student_enrollments se
    JOIN class_schedules cs ON se.schedule_id = cs.id
    WHERE se.student_id = ? AND se.is_active = 1
    ORDER BY se.subject_name, cs.day_of_week
  `;

  db.query(sql, [student_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch enrollments", error: err });
    }

    console.log(`✅ Fetched ${results.length} enrollments for student ${student_id}`);

    res.status(200).json({
      message: "Enrollments fetched successfully",
      enrollments: results,
      totalEnrollments: results.length
    });
  });
});

// 📍 GET ENROLLED STUDENTS FOR TEACHER'S COURSE
app.post("/get-enrolled-students", (req, res) => {
  const { teacher_id, schedule_id, subject_name } = req.body;

  console.log('📋 Fetching enrolled students:');
  console.log(`   Teacher ID: ${teacher_id}`);
  console.log(`   Schedule ID: ${schedule_id}`);
  console.log(`   Subject: ${subject_name}`);

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  let sql, params;

  if (schedule_id) {
    // Get students for specific schedule
    sql = `
      SELECT 
        se.*,
        sr.profile_image,
        sr.phone_number,
        sr.arid_no
      FROM student_enrollments se
      LEFT JOIN student_registration sr ON se.student_id = sr.id
      WHERE se.schedule_id = ? 
        AND se.teacher_id = ? 
        AND se.is_active = 1
      ORDER BY se.student_name
    `;
    params = [schedule_id, teacher_id];
  } else if (subject_name) {
    // Get students for all sections of this subject
    sql = `
      SELECT 
        se.*,
        sr.profile_image,
        sr.phone_number,
        sr.arid_no,
        cs.day_of_week,
        cs.start_time,
        cs.end_time,
        cs.room_number
      FROM student_enrollments se
      LEFT JOIN student_registration sr ON se.student_id = sr.id
      LEFT JOIN class_schedules cs ON se.schedule_id = cs.id
      WHERE se.teacher_id = ? 
        AND se.subject_name = ?
        AND se.is_active = 1
      ORDER BY se.student_section, se.student_name
    `;
    params = [teacher_id, subject_name];
  } else {
    // Get all enrolled students for this teacher
    sql = `
      SELECT 
        se.*,
        sr.profile_image,
        sr.phone_number,
        sr.arid_no,
        cs.day_of_week,
        cs.start_time,
        cs.end_time,
        cs.room_number
      FROM student_enrollments se
      LEFT JOIN student_registration sr ON se.student_id = sr.id
      LEFT JOIN class_schedules cs ON se.schedule_id = cs.id
      WHERE se.teacher_id = ? 
        AND se.is_active = 1
      ORDER BY se.subject_name, se.student_section, se.student_name
    `;
    params = [teacher_id];
  }

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch students", error: err });
    }

    // Group by section if viewing all sections of a subject
    let groupedBySection = {};
    if (subject_name && !schedule_id) {
      results.forEach(student => {
        const key = `${student.student_degree}-${student.student_section}`;
        if (!groupedBySection[key]) {
          groupedBySection[key] = [];
        }
        groupedBySection[key].push(student);
      });
    }

    console.log(`✅ Fetched ${results.length} enrolled students`);

    res.status(200).json({
      message: "Students fetched successfully",
      students: results,
      groupedBySection: Object.keys(groupedBySection).length > 0 ? groupedBySection : null,
      totalStudents: results.length
    });
  });
});

// 📍 GET TEACHER'S COURSES WITH ENROLLMENT COUNT
app.post("/get-teacher-courses-with-enrollments", (req, res) => {
  const { teacher_id } = req.body;

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  const sql = `
    SELECT 
      cs.id as schedule_id,
      cs.subject_name,
      cs.class_code,
      cs.degree,
      cs.section,
      cs.semester_no,
      cs.day_of_week,
      cs.start_time,
      cs.end_time,
      cs.room_number,
      COUNT(se.id) as enrolled_count
    FROM class_schedules cs
    LEFT JOIN student_enrollments se ON 
      cs.id = se.schedule_id 
      AND se.is_active = 1
    WHERE cs.teacher_id = ? 
      AND cs.is_active = 1
    GROUP BY cs.id
    ORDER BY cs.subject_name, cs.section
  `;

  db.query(sql, [teacher_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch courses", error: err });
    }

    // Group by subject
    const courseMap = {};
    results.forEach(row => {
      const key = row.subject_name;
      if (!courseMap[key]) {
        courseMap[key] = {
          subject_name: row.subject_name,
          class_code: row.class_code,
          total_enrolled: 0,
          sections: []
        };
      }

      courseMap[key].total_enrolled += row.enrolled_count;
      courseMap[key].sections.push({
        schedule_id: row.schedule_id,
        degree: row.degree,
        section: row.section,
        semester_no: row.semester_no,
        day_of_week: row.day_of_week,
        start_time: row.start_time,
        end_time: row.end_time,
        room_number: row.room_number,
        enrolled_count: row.enrolled_count
      });
    });

    const courses = Object.values(courseMap);

    console.log(`✅ Teacher ${teacher_id} has ${courses.length} courses with ${results.length} sections`);

    res.status(200).json({
      message: "Courses fetched successfully",
      courses: courses,
      totalCourses: courses.length,
      totalSections: results.length
    });
  });
});

console.log("✅ Student Enrollment endpoints initialized");


// ================= GPS-BASED ATTENDANCE ENDPOINTS =================

// 📍 START ATTENDANCE SESSION (Teacher enables GPS-based attendance)
app.post("/start-attendance-session", (req, res) => {
  const { teacher_id, course_id, degree, section, semester_no, latitude, longitude } = req.body;

  console.log('📍 Starting GPS attendance session:', {
    teacher_id,
    course_id,
    degree,
    section,
    latitude,
    longitude
  });

  if (!teacher_id || !course_id || !degree || !section || !semester_no || !latitude || !longitude) {
    return res.status(400).json({ message: "All fields required including GPS coordinates" });
  }

  // Get schedule_id
  const scheduleSql = `
    SELECT id FROM class_schedules
    WHERE teacher_id = ? 
      AND subject_name = ?
      AND degree = ?
      AND section = ?
      AND semester_no = ?
      AND is_active = 1
    LIMIT 1
  `;

  db.query(scheduleSql, [teacher_id, course_id, degree, section, semester_no], (schedErr, schedResults) => {
    if (schedErr) {
      console.error("❌ Schedule Error:", schedErr);
      return res.status(500).json({ message: "Database error", error: schedErr });
    }

    if (schedResults.length === 0) {
      return res.status(404).json({ message: "Schedule not found" });
    }

    const schedule_id = schedResults[0].id;
    const today = new Date().toISOString().split('T')[0];

    // Check if session already exists for today
    const checkSql = `
      SELECT id FROM attendance_sessions
      WHERE schedule_id = ? AND date = ? AND status = 'active'
      LIMIT 1
    `;

    db.query(checkSql, [schedule_id, today], (checkErr, checkResults) => {
      if (checkErr) {
        console.error("❌ Check Error:", checkErr);
        return res.status(500).json({ message: "Database error" });
      }

      if (checkResults.length > 0) {
        return res.status(400).json({ 
          message: "Active attendance session already exists for today",
          session_id: checkResults[0].id
        });
      }

      // Create new attendance session
      const insertSql = `
        INSERT INTO attendance_sessions
        (teacher_id, schedule_id, date, latitude, longitude, status, radius_meters, started_at)
        VALUES (?, ?, ?, ?, ?, 'active', 122968580, NOW())
      `;

      db.query(
        insertSql,
        [teacher_id, schedule_id, today, latitude, longitude],
        (insertErr, result) => {
          if (insertErr) {
            console.error("❌ Insert Error:", insertErr);
            return res.status(500).json({ message: "Failed to start session", error: insertErr });
          }

          console.log(`✅ Attendance session started: ${result.insertId}`);

          res.status(201).json({
            message: "Attendance session started successfully",
            session_id: result.insertId,
            schedule_id: schedule_id,
            latitude: latitude,
            longitude: longitude,
            radius_meters: 122968580
          });
        }
      );
    });
  });
});

// 📍 END ATTENDANCE SESSION (Teacher closes attendance)
// 📍 END ATTENDANCE SESSION (Teacher closes attendance)
app.post("/end-attendance-session", (req, res) => {
  const { session_id, teacher_id } = req.body;

  console.log('🛑 Ending attendance session:', session_id);

  if (!session_id || !teacher_id) {
    return res.status(400).json({ message: "Session ID and Teacher ID required" });
  }

  // First check if already closed/ended
  const checkSql = `
    SELECT id, status FROM attendance_sessions
    WHERE id = ? AND teacher_id = ?
  `;

  db.query(checkSql, [session_id, teacher_id], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Check Error:", checkErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (checkResults.length === 0) {
      return res.status(404).json({ message: "Session not found" });
    }

    if (checkResults[0].status !== 'active') {
      console.log(`✅ Session ${session_id} already ended`);
      return res.status(200).json({
        message: "Attendance session already ended"
      });
    }

    // Use 'ended' instead of 'closed' to avoid constraint conflict
    const updateSql = `
      UPDATE attendance_sessions
      SET status = 'ended', ended_at = NOW()
      WHERE id = ? AND teacher_id = ? AND status = 'active'
    `;

    db.query(updateSql, [session_id, teacher_id], (err, result) => {
      if (err) {
        console.error("❌ Update Error:", err);
        return res.status(500).json({ message: "Failed to end session", error: err });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({ message: "Active session not found" });
      }

      console.log(`✅ Attendance session ${session_id} ended`);

      res.status(200).json({
        message: "Attendance session ended successfully"
      });
    });
  });
});

// 📍 GET ACTIVE SESSION (Check if teacher has active session)
app.post("/get-active-session", (req, res) => {
  const { teacher_id, course_id, degree, section, semester_no } = req.body;

  if (!teacher_id || !course_id || !degree || !section || !semester_no) {
    return res.status(400).json({ message: "All fields required" });
  }

  const sql = `
    SELECT 
      ats.*,
      cs.subject_name,
      cs.class_code
    FROM attendance_sessions ats
    JOIN class_schedules cs ON ats.schedule_id = cs.id
    WHERE ats.teacher_id = ?
      AND cs.subject_name = ?
      AND cs.degree = ?
      AND cs.section = ?
      AND cs.semester_no = ?
      AND ats.status = 'active'
      AND ats.date = CURDATE()
    ORDER BY ats.started_at DESC
    LIMIT 1
  `;

  db.query(sql, [teacher_id, course_id, degree, section, semester_no], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error" });
    }

    if (results.length === 0) {
      return res.status(200).json({
        message: "No active session",
        active_session: null
      });
    }

    res.status(200).json({
      message: "Active session found",
      active_session: results[0]
    });
  });
});

// 📍 CHECK STUDENT SESSION AVAILABILITY (Student checks if they can mark attendance)
app.post("/check-session-for-student", (req, res) => {
  const { student_id, schedule_id } = req.body;

  console.log('🔍 Checking session availability for student:', student_id);

  if (!student_id || !schedule_id) {
    return res.status(400).json({ message: "Student ID and Schedule ID required" });
  }

  const today = new Date().toISOString().split('T')[0];

  // Check for active session
  const sessionSql = `
    SELECT 
      id as session_id,
      latitude,
      longitude,
      radius_meters,
      started_at
    FROM attendance_sessions
    WHERE schedule_id = ?
      AND date = ?
      AND status = 'active'
    LIMIT 1
  `;

  db.query(sessionSql, [schedule_id, today], (sessionErr, sessionResults) => {
    if (sessionErr) {
      console.error("❌ Session Error:", sessionErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (sessionResults.length === 0) {
      return res.status(200).json({
        message: "No active session",
        can_mark_attendance: false,
        reason: "Teacher has not started attendance session yet"
      });
    }

    // Check if student already marked attendance
    const checkSql = `
      SELECT id FROM attendance_records
      WHERE student_id = ? AND schedule_id = ? AND date = ?
      LIMIT 1
    `;

    db.query(checkSql, [student_id, schedule_id, today], (checkErr, checkResults) => {
      if (checkErr) {
        console.error("❌ Check Error:", checkErr);
        return res.status(500).json({ message: "Database error" });
      }

      if (checkResults.length > 0) {
        return res.status(200).json({
          message: "Already marked",
          can_mark_attendance: false,
          reason: "You have already marked attendance for today"
        });
      }

      // Session is active and student hasn't marked attendance
      const session = sessionResults[0];
      res.status(200).json({
        message: "Session available",
        can_mark_attendance: true,
        session_id: session.session_id,
        teacher_latitude: session.latitude,
        teacher_longitude: session.longitude,
        radius_meters: session.radius_meters
      });
    });
  });
});

// 📍 MARK GPS ATTENDANCE (Student marks attendance with location verification)
app.post("/mark-gps-attendance", (req, res) => {
  const { 
    student_id, 
    student_name, 
    schedule_id, 
    session_id,
    latitude, 
    longitude 
  } = req.body;

  console.log('📍 GPS attendance request:', {
    student_id,
    schedule_id,
    session_id,
    student_location: { latitude, longitude }
  });

  if (!student_id || !student_name || !schedule_id || !session_id || !latitude || !longitude) {
    return res.status(400).json({ message: "All fields required including GPS coordinates" });
  }

  const today = new Date().toISOString().split('T')[0];
  const now = new Date().toTimeString().split(' ')[0];

  // Get session details
  const sessionSql = `
    SELECT 
      latitude as teacher_lat,
      longitude as teacher_lng,
      radius_meters,
      status
    FROM attendance_sessions
    WHERE id = ? AND schedule_id = ? AND date = ? AND status = 'active'
    LIMIT 1
  `;

  db.query(sessionSql, [session_id, schedule_id, today], (sessionErr, sessionResults) => {
    if (sessionErr) {
      console.error("❌ Session Error:", sessionErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (sessionResults.length === 0) {
      return res.status(400).json({ 
        message: "No active session found. Teacher may have closed attendance." 
      });
    }

    const session = sessionResults[0];
    
    // Calculate distance using Haversine formula
    const distance = calculateDistance(
      latitude,
      longitude,
      session.teacher_lat,
      session.teacher_lng
    );

    console.log(`📏 Distance from teacher: ${distance.toFixed(2)} meters`);

    if (distance > session.radius_meters) {
      return res.status(400).json({
        message: `You are too far from the classroom. Distance: ${distance.toFixed(0)}m (Max: ${session.radius_meters}m)`,
        distance_meters: Math.round(distance),
        max_distance: session.radius_meters
      });
    }

    // Check if already marked
    const checkSql = `
      SELECT id FROM attendance_records
      WHERE student_id = ? AND schedule_id = ? AND date = ?
      LIMIT 1
    `;

    db.query(checkSql, [student_id, schedule_id, today], (checkErr, checkResults) => {
      if (checkErr) {
        console.error("❌ Check Error:", checkErr);
        return res.status(500).json({ message: "Database error" });
      }

      if (checkResults.length > 0) {
        return res.status(400).json({ 
          message: "Attendance already marked for today" 
        });
      }

      // Mark attendance
      const insertSql = `
        INSERT INTO attendance_records
        (student_id, student_name, schedule_id, date, time, status, marked_by, 
         session_id, student_latitude, student_longitude, distance_meters)
        VALUES (?, ?, ?, ?, ?, 'present', 'gps', ?, ?, ?, ?)
      `;

      db.query(
        insertSql,
        [student_id, student_name, schedule_id, today, now, session_id, latitude, longitude, Math.round(distance)],
        (insertErr, result) => {
          if (insertErr) {
            console.error("❌ Insert Error:", insertErr);
            return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
          }

          console.log(`✅ GPS attendance marked for student ${student_id} (${distance.toFixed(2)}m away)`);

          res.status(201).json({
            message: "Attendance marked successfully",
            attendance_id: result.insertId,
            distance_meters: Math.round(distance)
          });
        }
      );
    });
  });
});

// 📍 GET SESSION STATISTICS (For teacher to see who marked attendance)
app.post("/get-session-statistics", (req, res) => {
  const { session_id, teacher_id } = req.body;

  if (!session_id || !teacher_id) {
    return res.status(400).json({ message: "Session ID and Teacher ID required" });
  }

  const sql = `
    SELECT 
      ar.student_id,
      ar.student_name,
      ar.time as marked_at,
      ar.distance_meters,
      ar.student_latitude,
      ar.student_longitude
    FROM attendance_records ar
    WHERE ar.session_id = ?
    ORDER BY ar.time DESC
  `;

  db.query(sql, [session_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Database error" });
    }

    res.status(200).json({
      message: "Session statistics retrieved",
      total_marked: results.length,
      students: results
    });
  });
});

// Helper function: Calculate distance between two GPS coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

console.log("✅ GPS-based attendance endpoints initialized");

// ================= ATTENDANCE ENDPOINTS =================

// 📍 GET STUDENT ATTENDANCE (for specific schedule)
app.post("/get-student-attendance", (req, res) => {
  const { student_id, schedule_id } = req.body;

  console.log('📊 Fetching attendance for student:', student_id, 'schedule:', schedule_id);

  if (!student_id || !schedule_id) {
    return res.status(400).json({ message: "Student ID and Schedule ID required" });
  }

  // Get attendance records
  const recordsSql = `
    SELECT 
      date,
      time,
      status
    FROM attendance_records
    WHERE student_id = ? AND schedule_id = ?
    ORDER BY date DESC, time DESC
  `;

  db.query(recordsSql, [student_id, schedule_id], (err, records) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch attendance", error: err });
    }

    // Calculate statistics
    const totalClasses = records.length;
    const attendedClasses = records.filter(r => r.status === 'present').length;
    const percentage = totalClasses > 0 ? ((attendedClasses / totalClasses) * 100).toFixed(2) : 0;

    console.log(`✅ Student ${student_id}: ${attendedClasses}/${totalClasses} (${percentage}%)`);

    res.status(200).json({
      message: "Attendance fetched successfully",
      totalClasses,
      attendedClasses,
      percentage: parseFloat(percentage),
      records
    });
  });
});

// 📍 MARK SELF ATTENDANCE (Student marks own attendance)
app.post("/mark-self-attendance", (req, res) => {
  const { student_id, schedule_id, student_name } = req.body;

  console.log('✍️ Self-attendance request:', { student_id, schedule_id, student_name });

  if (!student_id || !schedule_id || !student_name) {
    return res.status(400).json({ message: "All fields required" });
  }

  const today = new Date().toISOString().split('T')[0];
  const now = new Date().toTimeString().split(' ')[0];

  // Check if already marked today
  const checkSql = `
    SELECT id FROM attendance_records
    WHERE student_id = ? AND schedule_id = ? AND date = ?
    LIMIT 1
  `;

  db.query(checkSql, [student_id, schedule_id, today], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Check Error:", checkErr);
      return res.status(500).json({ message: "Database error", error: checkErr });
    }

    if (checkResults.length > 0) {
      return res.status(400).json({ 
        message: "Attendance already marked for today" 
      });
    }

    // Mark attendance
    const insertSql = `
      INSERT INTO attendance_records
      (student_id, student_name, schedule_id, date, time, status, marked_by)
      VALUES (?, ?, ?, ?, ?, 'present', 'student')
    `;

    db.query(
      insertSql,
      [student_id, student_name, schedule_id, today, now],
      (insertErr, result) => {
        if (insertErr) {
          console.error("❌ Insert Error:", insertErr);
          return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
        }

        console.log(`✅ Self-attendance marked for student ${student_id}`);

        res.status(201).json({
          message: "Attendance marked successfully",
          attendance_id: result.insertId
        });
      }
    );
  });
});

// 📍 GET CLASS STATISTICS (for teacher dashboard)
app.post("/get-class-statistics", (req, res) => {
  const { schedule_id } = req.body;

  if (!schedule_id) {
    return res.status(400).json({ message: "Schedule ID required" });
  }

  // Get unique dates (classes taken)
  const classesSql = `
    SELECT COUNT(DISTINCT date) as total_classes
    FROM attendance_records
    WHERE schedule_id = ?
  `;

  // Get enrolled students count
  const studentsSql = `
    SELECT COUNT(*) as total_students
    FROM student_enrollments
    WHERE schedule_id = ? AND is_active = 1
  `;

  // Get average attendance
  const attendanceSql = `
    SELECT 
      COUNT(CASE WHEN status = 'present' THEN 1 END) as present_count,
      COUNT(*) as total_records
    FROM attendance_records
    WHERE schedule_id = ?
  `;

  db.query(classesSql, [schedule_id], (err1, classResults) => {
    if (err1) {
      console.error("❌ Error:", err1);
      return res.status(500).json({ message: "Database error" });
    }

    db.query(studentsSql, [schedule_id], (err2, studentResults) => {
      if (err2) {
        console.error("❌ Error:", err2);
        return res.status(500).json({ message: "Database error" });
      }

      db.query(attendanceSql, [schedule_id], (err3, attendanceResults) => {
        if (err3) {
          console.error("❌ Error:", err3);
          return res.status(500).json({ message: "Database error" });
        }

        const totalClasses = classResults[0].total_classes || 0;
        const totalStudents = studentResults[0].total_students || 0;
        const presentCount = attendanceResults[0].present_count || 0;
        const totalRecords = attendanceResults[0].total_records || 0;
        const averageAttendance = totalRecords > 0 
          ? ((presentCount / totalRecords) * 100).toFixed(2) 
          : 0;

        res.status(200).json({
          message: "Statistics fetched successfully",
          totalClassesTaken: totalClasses,
          totalStudents,
          averageAttendance: parseFloat(averageAttendance)
        });
      });
    });
  });
});

// 📍 MARK CLASS ATTENDANCE (Teacher marks attendance for entire class)
app.post("/mark-class-attendance", (req, res) => {
  const { teacher_id, schedule_id, attendance, date } = req.body;

  console.log('📝 Class attendance marking:');
  console.log(`   Teacher: ${teacher_id}, Schedule: ${schedule_id}`);
  console.log(`   Date: ${date}, Students: ${attendance.length}`);

  if (!teacher_id || !schedule_id || !attendance || !date) {
    return res.status(400).json({ message: "All fields required" });
  }

  const now = new Date().toTimeString().split(' ')[0];

  // Check if attendance already marked for this date
  const checkSql = `
    SELECT id FROM attendance_records
    WHERE schedule_id = ? AND date = ?
    LIMIT 1
  `;

  db.query(checkSql, [schedule_id, date], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Check Error:", checkErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (checkResults.length > 0) {
      return res.status(400).json({ 
        message: "Attendance already marked for this date. Please edit existing records." 
      });
    }

    // Insert attendance records
    const insertSql = `
      INSERT INTO attendance_records
      (student_id, student_name, schedule_id, date, time, status, marked_by, teacher_id)
      VALUES ?
    `;

    const values = attendance.map(record => [
      record.student_id,
      record.student_name,
      schedule_id,
      date,
      now,
      record.status,
      'teacher',
      teacher_id
    ]);

    db.query(insertSql, [values], (insertErr, result) => {
      if (insertErr) {
        console.error("❌ Insert Error:", insertErr);
        return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
      }

      const presentCount = attendance.filter(r => r.status === 'present').length;
      const absentCount = attendance.length - presentCount;

      console.log(`✅ Attendance marked: ${presentCount} present, ${absentCount} absent`);

      res.status(201).json({
        message: `Attendance marked successfully for ${attendance.length} students`,
        presentCount,
        absentCount,
        totalRecords: result.affectedRows
      });
    });
  });
});

// 📍 UPDATE ATTENDANCE RECORD (Edit existing attendance)
app.post("/update-attendance-record", (req, res) => {
  const { record_id, status, teacher_id } = req.body;

  if (!record_id || !status || !teacher_id) {
    return res.status(400).json({ message: "All fields required" });
  }

  const updateSql = `
    UPDATE attendance_records
    SET status = ?, updated_at = NOW()
    WHERE id = ? AND teacher_id = ?
  `;

  db.query(updateSql, [status, record_id, teacher_id], (err, result) => {
    if (err) {
      console.error("❌ Update Error:", err);
      return res.status(500).json({ message: "Failed to update", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Record not found" });
    }

    console.log(`✅ Attendance record ${record_id} updated to ${status}`);

    res.status(200).json({
      message: "Attendance updated successfully"
    });
  });
});

// 📍 GET ATTENDANCE HISTORY (for detailed view)
app.post("/get-attendance-history", (req, res) => {
  const { schedule_id, start_date, end_date } = req.body;

  if (!schedule_id) {
    return res.status(400).json({ message: "Schedule ID required" });
  }

  let sql = `
    SELECT 
      ar.*,
      se.student_email,
      se.student_section
    FROM attendance_records ar
    LEFT JOIN student_enrollments se ON 
      ar.student_id = se.student_id AND ar.schedule_id = se.schedule_id
    WHERE ar.schedule_id = ?
  `;

  const params = [schedule_id];

  if (start_date && end_date) {
    sql += ` AND ar.date BETWEEN ? AND ?`;
    params.push(start_date, end_date);
  }

  sql += ` ORDER BY ar.date DESC, ar.student_name`;

  db.query(sql, params, (err, results) => {
    if (err) {
      console.error("❌ Error:", err);
      return res.status(500).json({ message: "Failed to fetch history", error: err });
    }

    // Group by date
    const groupedByDate = {};
    results.forEach(record => {
      const date = record.date;
      if (!groupedByDate[date]) {
        groupedByDate[date] = [];
      }
      groupedByDate[date].push(record);
    });

    res.status(200).json({
      message: "History fetched successfully",
      records: results,
      groupedByDate,
      totalRecords: results.length
    });
  });
});

console.log("✅ Attendance endpoints initialized");


// ================= UPDATED ATTENDANCE ENDPOINTS =================

// 📍 GET TEACHER SUBJECTS GROUPED (for teacher attendance page)
app.post("/get-teacher-subjects-grouped", (req, res) => {
  const { teacher_id } = req.body;

  console.log('📚 Fetching grouped subjects for teacher:', teacher_id);

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  const sql = `
    SELECT 
      cs.subject_name as course_name,
      cs.class_code as course_code,
      cs.subject_name as course_id,
      COUNT(DISTINCT CONCAT(cs.degree, '-', cs.section)) as total_sections,
      COUNT(DISTINCT se.student_id) as total_students,
      COALESCE(AVG(
        CASE 
          WHEN total_classes.total > 0 
          THEN (attended_classes.attended / total_classes.total * 100)
          ELSE 0
        END
      ), 0) as avg_attendance
    FROM class_schedules cs
    LEFT JOIN student_enrollments se ON 
      cs.id = se.schedule_id AND se.is_active = 1
    LEFT JOIN (
      SELECT 
        student_id, 
        schedule_id, 
        COUNT(*) as total
      FROM attendance_records
      GROUP BY student_id, schedule_id
    ) total_classes ON se.student_id = total_classes.student_id AND cs.id = total_classes.schedule_id
    LEFT JOIN (
      SELECT 
        student_id, 
        schedule_id, 
        COUNT(*) as attended
      FROM attendance_records
      WHERE status = 'present'
      GROUP BY student_id, schedule_id
    ) attended_classes ON se.student_id = attended_classes.student_id AND cs.id = attended_classes.schedule_id
    WHERE cs.teacher_id = ? AND cs.is_active = 1
    GROUP BY cs.subject_name, cs.class_code
    ORDER BY cs.subject_name
  `;

  db.query(sql, [teacher_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ 
        message: "Failed to fetch teacher subjects",
        error: err.message 
      });
    }

    console.log(`✅ Found ${results.length} subjects for teacher ${teacher_id}`);

    res.status(200).json({
      message: "Teacher subjects retrieved successfully",
      subjects: results
    });
  });
});

// ============================================================================
// 📍 FIXED: GET SUBJECT SECTIONS (removes duplicates)
// ============================================================================
app.post("/get-subject-sections", (req, res) => {
  const { teacher_id, course_id } = req.body;

  console.log('📋 Fetching sections for:', { teacher_id, course_id });

  if (!teacher_id || !course_id) {
    return res.status(400).json({ message: "Teacher ID and Course ID required" });
  }

  // ✅ FIXED: Group by degree, section, semester_no ONLY
  // This prevents duplicates caused by different day_of_week or time slots
  const sql = `
    SELECT 
      MIN(cs.id) as schedule_id,
      cs.degree,
      cs.section,
      cs.semester_no,
      GROUP_CONCAT(DISTINCT cs.day_of_week ORDER BY FIELD(cs.day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday') SEPARATOR ', ') as days,
      MIN(cs.start_time) as start_time,
      MAX(cs.end_time) as end_time,
      COUNT(DISTINCT se.student_id) as enrolled_count,
      COUNT(DISTINCT ar.date) as classes_taken,
      COALESCE(AVG(
        CASE 
          WHEN ar.status = 'present' THEN 100
          ELSE 0
        END
      ), 0) as avg_attendance
    FROM class_schedules cs
    LEFT JOIN student_enrollments se ON 
      cs.id = se.schedule_id AND se.is_active = 1
    LEFT JOIN attendance_records ar ON 
      se.student_id = ar.student_id AND cs.id = ar.schedule_id
    WHERE cs.teacher_id = ? 
      AND cs.subject_name = ?
      AND cs.is_active = 1
    GROUP BY cs.degree, cs.section, cs.semester_no
    ORDER BY cs.degree, cs.section
  `;

  db.query(sql, [teacher_id, course_id], (err, results) => {
    if (err) {
      console.error("❌ Database Error:", err);
      return res.status(500).json({ message: "Failed to fetch sections", error: err });
    }

    console.log(`✅ Found ${results.length} unique sections (deduplicated)`);

    res.status(200).json({
      message: "Sections fetched successfully",
      sections: results
    });
  });
});

// 📍 GET SECTION STUDENTS WITH ATTENDANCE (for marking attendance)
app.post("/get-section-students-attendance", (req, res) => {
  const { teacher_id, course_id, degree, section, semester_no } = req.body;

  console.log('👥 Fetching students for attendance:', { teacher_id, course_id, degree, section });

  if (!teacher_id || !course_id || !degree || !section || !semester_no) {
    return res.status(400).json({ message: "All fields required" });
  }

  const sql = `
    SELECT 
      se.student_id,
      se.student_name,
      se.student_email,
      sr.arid_no,
      COUNT(ar.id) as total_classes,
      COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as attended_classes
    FROM student_enrollments se
    LEFT JOIN student_registration sr ON se.student_id = sr.id
    LEFT JOIN class_schedules cs ON 
      se.schedule_id = cs.id AND 
      cs.teacher_id = ? AND 
      cs.subject_name = ? AND
      cs.degree = ? AND 
      cs.section = ? AND
      cs.semester_no = ?
    LEFT JOIN attendance_records ar ON 
      se.student_id = ar.student_id AND cs.id = ar.schedule_id
    WHERE se.is_active = 1
      AND se.teacher_id = ?
      AND se.student_degree = ?
      AND se.student_section = ?
      AND se.student_semester_no = ?
    GROUP BY se.student_id, se.student_name, se.student_email, sr.arid_no
    ORDER BY se.student_name
  `;

  db.query(
    sql, 
    [teacher_id, course_id, degree, section, semester_no, teacher_id, degree, section, semester_no],
    (err, results) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to fetch students", error: err });
      }

      console.log(`✅ Found ${results.length} students`);

      res.status(200).json({
        message: "Students fetched successfully",
        students: results
      });
    }
  );
});

// 📍 MARK ATTENDANCE BY COURSE (teacher marks for specific course/section)
app.post("/mark-attendance-by-course", (req, res) => {
  const { teacher_id, course_id, degree, section, semester_no, attendance, date } = req.body;

  console.log('📝 Marking attendance by course:');
  console.log(`   Teacher: ${teacher_id}`);
  console.log(`   Course: ${course_id}`);
  console.log(`   Section: ${degree}-${section}`);
  console.log(`   Date: ${date}`);
  console.log(`   Students: ${attendance.length}`);

  if (!teacher_id || !course_id || !degree || !section || !semester_no || !attendance || !date) {
    return res.status(400).json({ message: "All fields required" });
  }

  // First, get the schedule_id
  const scheduleSql = `
    SELECT id FROM class_schedules
    WHERE teacher_id = ? 
      AND subject_name = ?
      AND degree = ?
      AND section = ?
      AND semester_no = ?
      AND is_active = 1
    LIMIT 1
  `;

  db.query(scheduleSql, [teacher_id, course_id, degree, section, semester_no], (schedErr, schedResults) => {
    if (schedErr) {
      console.error("❌ Schedule Error:", schedErr);
      return res.status(500).json({ message: "Database error", error: schedErr });
    }

    if (schedResults.length === 0) {
      return res.status(404).json({ message: "Schedule not found" });
    }

    const schedule_id = schedResults[0].id;
    const now = new Date().toTimeString().split(' ')[0];

    // Check if attendance already marked for this date
    const checkSql = `
      SELECT id FROM attendance_records
      WHERE schedule_id = ? AND date = ?
      LIMIT 1
    `;

    db.query(checkSql, [schedule_id, date], (checkErr, checkResults) => {
      if (checkErr) {
        console.error("❌ Check Error:", checkErr);
        return res.status(500).json({ message: "Database error" });
      }

      if (checkResults.length > 0) {
        return res.status(400).json({ 
          message: "Attendance already marked for this date" 
        });
      }

      // Insert attendance records
      const insertSql = `
        INSERT INTO attendance_records
        (student_id, student_name, schedule_id, date, time, status, marked_by, teacher_id)
        VALUES ?
      `;

      const values = attendance.map(record => [
        record.student_id,
        record.student_name,
        schedule_id,
        date,
        now,
        record.status,
        'teacher',
        teacher_id
      ]);

      db.query(insertSql, [values], (insertErr, result) => {
        if (insertErr) {
          console.error("❌ Insert Error:", insertErr);
          return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
        }

        const presentCount = attendance.filter(r => r.status === 'present').length;
        const absentCount = attendance.length - presentCount;

        console.log(`✅ Attendance marked: ${presentCount} present, ${absentCount} absent`);

        res.status(201).json({
          message: `Attendance marked successfully for ${attendance.length} students`,
          presentCount,
          absentCount,
          totalRecords: result.affectedRows
        });
      });
    });
  });
});

// 📍 ADD SINGLE ATTENDANCE RECORD (teacher can increase student attendance)
app.post("/add-single-attendance-record", (req, res) => {
  const { teacher_id, student_id, student_name, course_id, degree, section, semester_no, date, status } = req.body;

  console.log('➕ Adding single attendance record:', { student_id, course_id, date, status });

  if (!teacher_id || !student_id || !student_name || !course_id || !degree || !section || !semester_no || !date || !status) {
    return res.status(400).json({ message: "All fields required" });
  }

  // Get schedule_id
  const scheduleSql = `
    SELECT id FROM class_schedules
    WHERE teacher_id = ? 
      AND subject_name = ?
      AND degree = ?
      AND section = ?
      AND semester_no = ?
      AND is_active = 1
    LIMIT 1
  `;

  db.query(scheduleSql, [teacher_id, course_id, degree, section, semester_no], (schedErr, schedResults) => {
    if (schedErr) {
      console.error("❌ Schedule Error:", schedErr);
      return res.status(500).json({ message: "Database error", error: schedErr });
    }

    if (schedResults.length === 0) {
      return res.status(404).json({ message: "Schedule not found" });
    }

    const schedule_id = schedResults[0].id;
    const now = new Date().toTimeString().split(' ')[0];

    // Check if attendance already exists for this student on this date
    const checkSql = `
      SELECT id FROM attendance_records
      WHERE student_id = ? AND schedule_id = ? AND date = ?
      LIMIT 1
    `;

    db.query(checkSql, [student_id, schedule_id, date], (checkErr, checkResults) => {
      if (checkErr) {
        console.error("❌ Check Error:", checkErr);
        return res.status(500).json({ message: "Database error" });
      }

      if (checkResults.length > 0) {
        return res.status(400).json({ 
          message: "Attendance already exists for this date. Please edit the existing record instead." 
        });
      }

      // Insert new attendance record
      const insertSql = `
        INSERT INTO attendance_records
        (student_id, student_name, schedule_id, date, time, status, marked_by, teacher_id)
        VALUES (?, ?, ?, ?, ?, ?, 'teacher', ?)
      `;

      db.query(insertSql, [student_id, student_name, schedule_id, date, now, status, teacher_id], (insertErr, result) => {
        if (insertErr) {
          console.error("❌ Insert Error:", insertErr);
          return res.status(500).json({ message: "Failed to add attendance", error: insertErr });
        }

        console.log(`✅ Attendance record added for student ${student_id} on ${date}`);

        res.status(201).json({
          message: "Attendance record added successfully",
          record_id: result.insertId
        });
      });
    });
  });
});

// 📍 GET STUDENT ATTENDANCE DETAILS (for student view with all courses)
app.post("/get-student-attendance-details", (req, res) => {
  const { student_id } = req.body;

  console.log('📊 Fetching attendance details for student:', student_id);

  if (!student_id) {
    return res.status(400).json({ message: "Student ID required" });
  }

  // First, get all enrolled courses
  const enrollmentSql = `
    SELECT 
      se.schedule_id,
      se.subject_name as course_name,
      se.class_code as course_code,
      se.teacher_id,
      se.teacher_name
    FROM student_enrollments se
    WHERE se.student_id = ? AND se.is_active = 1
    ORDER BY se.subject_name
  `;

  db.query(enrollmentSql, [student_id], (enrollErr, enrollments) => {
    if (enrollErr) {
      console.error("❌ Database Error:", enrollErr);
      return res.status(500).json({ message: "Failed to fetch enrollments", error: enrollErr });
    }

    if (enrollments.length === 0) {
      return res.status(200).json({
        message: "No enrollments found",
        subjects: []
      });
    }

    // For each enrollment, get attendance records
    const subjects = [];
    let processed = 0;

    enrollments.forEach(enrollment => {
      const attendanceSql = `
        SELECT 
          date,
          status,
          time
        FROM attendance_records
        WHERE student_id = ? AND schedule_id = ?
        ORDER BY date DESC
      `;

      db.query(attendanceSql, [student_id, enrollment.schedule_id], (attErr, records) => {
        if (attErr) {
          console.error("❌ Attendance Error:", attErr);
        }

        const totalClasses = records ? records.length : 0;
        const attendedClasses = records ? records.filter(r => r.status === 'present').length : 0;
        const percentage = totalClasses > 0 ? (attendedClasses / totalClasses * 100) : 0;

        subjects.push({
          schedule_id: enrollment.schedule_id,
          course_name: enrollment.course_name,
          course_code: enrollment.course_code,
          teacher_id: enrollment.teacher_id,
          teacher_name: enrollment.teacher_name,
          total_classes: totalClasses,
          attended_classes: attendedClasses,
          percentage: percentage,
          last_updated: records && records.length > 0 ? records[0].date : null,
          records: records || []
        });

        processed++;

        // When all are processed, send response
        if (processed === enrollments.length) {
          console.log(`✅ Found attendance for ${subjects.length} subjects`);

          res.status(200).json({
            message: "Attendance details fetched successfully",
            subjects: subjects
          });
        }
      });
    });
  });
});

// 📍 MARK SELF ATTENDANCE (student marks themselves present)
app.post("/mark-self-attendance", (req, res) => {
  const { student_id, schedule_id, student_name } = req.body;

  console.log('👤 Student marking self attendance:', { student_id, schedule_id });

  if (!student_id || !schedule_id || !student_name) {
    return res.status(400).json({ message: "Student ID, schedule ID, and student name required" });
  }

  const today = new Date().toISOString().split('T')[0];
  const now = new Date().toTimeString().split(' ')[0];

  // Check if already marked today
  const checkSql = `
    SELECT id FROM attendance_records
    WHERE student_id = ? AND schedule_id = ? AND date = ?
    LIMIT 1
  `;

  db.query(checkSql, [student_id, schedule_id, today], (checkErr, checkResults) => {
    if (checkErr) {
      console.error("❌ Check Error:", checkErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (checkResults.length > 0) {
      return res.status(400).json({ 
        message: "You have already marked attendance for today" 
      });
    }

    // Insert attendance record
    const insertSql = `
      INSERT INTO attendance_records
      (student_id, student_name, schedule_id, date, time, status, marked_by, teacher_id)
      VALUES (?, ?, ?, ?, ?, 'present', 'self', NULL)
    `;

    db.query(insertSql, [student_id, student_name, schedule_id, today, now], (insertErr, result) => {
      if (insertErr) {
        console.error("❌ Insert Error:", insertErr);
        return res.status(500).json({ message: "Failed to mark attendance", error: insertErr });
      }

      console.log(`✅ Self attendance marked for student ${student_id}`);

      res.status(201).json({
        message: "Attendance marked successfully",
        record_id: result.insertId
      });
    });
  });
});

// 📍 GET INDIVIDUAL STUDENT ATTENDANCE DETAILS (for teacher to view/edit specific student)
app.post("/get-student-attendance-by-course", (req, res) => {
  const { student_id, teacher_id, course_id, degree, section, semester_no } = req.body;

  console.log('📊 Fetching individual student attendance:', { student_id, course_id });

  if (!student_id || !teacher_id || !course_id || !degree || !section || !semester_no) {
    return res.status(400).json({ message: "All fields required" });
  }

  // Get schedule_id first
  const scheduleSql = `
    SELECT id FROM class_schedules
    WHERE teacher_id = ? 
      AND subject_name = ?
      AND degree = ?
      AND section = ?
      AND semester_no = ?
      AND is_active = 1
    LIMIT 1
  `;

  db.query(scheduleSql, [teacher_id, course_id, degree, section, semester_no], (schedErr, schedResults) => {
    if (schedErr) {
      console.error("❌ Schedule Error:", schedErr);
      return res.status(500).json({ message: "Database error", error: schedErr });
    }

    if (schedResults.length === 0) {
      return res.status(404).json({ message: "Schedule not found" });
    }

    const schedule_id = schedResults[0].id;

    // Get all attendance records for this student in this course
    const recordsSql = `
      SELECT 
        ar.id as record_id,
        ar.date,
        ar.time,
        ar.status,
        ar.marked_by,
        ar.created_at
      FROM attendance_records ar
      WHERE ar.student_id = ? AND ar.schedule_id = ?
      ORDER BY ar.date DESC, ar.time DESC
    `;

    db.query(recordsSql, [student_id, schedule_id], (err, records) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Failed to fetch records", error: err });
      }

      const totalClasses = records.length;
      const attendedClasses = records.filter(r => r.status === 'present').length;
      const percentage = totalClasses > 0 ? (attendedClasses / totalClasses * 100) : 0;

      console.log(`✅ Found ${records.length} attendance records for student ${student_id}`);

      res.status(200).json({
        message: "Student attendance fetched successfully",
        totalClasses,
        attendedClasses,
        percentage: parseFloat(percentage.toFixed(2)),
        records: records
      });
    });
  });
});

// 📍 UPDATE SINGLE ATTENDANCE RECORD (for teacher to correct attendance)
app.post("/update-single-attendance-record", (req, res) => {
  const { record_id, status, teacher_id } = req.body;

  console.log('✏️ Updating attendance record:', { record_id, status });

  if (!record_id || !status || !teacher_id) {
    return res.status(400).json({ message: "Record ID, status, and teacher ID required" });
  }

  // Verify the record belongs to this teacher
  const verifySql = `
    SELECT ar.id 
    FROM attendance_records ar
    WHERE ar.id = ? AND ar.teacher_id = ?
    LIMIT 1
  `;

  db.query(verifySql, [record_id, teacher_id], (verifyErr, verifyResults) => {
    if (verifyErr) {
      console.error("❌ Verification Error:", verifyErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (verifyResults.length === 0) {
      return res.status(403).json({ message: "Unauthorized to update this record" });
    }

    // Update the record
    const updateSql = `
      UPDATE attendance_records
      SET status = ?, updated_at = NOW()
      WHERE id = ?
    `;

    db.query(updateSql, [status, record_id], (updateErr, result) => {
      if (updateErr) {
        console.error("❌ Update Error:", updateErr);
        return res.status(500).json({ message: "Failed to update", error: updateErr });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({ message: "Record not found" });
      }

      console.log(`✅ Attendance record ${record_id} updated to ${status}`);

      res.status(200).json({
        message: "Attendance record updated successfully",
        record_id,
        new_status: status
      });
    });
  });
});

// 📍 DELETE ATTENDANCE RECORD (for teacher to remove incorrect entry)
app.post("/delete-attendance-record", (req, res) => {
  const { record_id, teacher_id } = req.body;

  console.log('🗑️ Deleting attendance record:', record_id);

  if (!record_id || !teacher_id) {
    return res.status(400).json({ message: "Record ID and teacher ID required" });
  }

  // Verify ownership
  const verifySql = `
    SELECT ar.id 
    FROM attendance_records ar
    WHERE ar.id = ? AND ar.teacher_id = ?
    LIMIT 1
  `;

  db.query(verifySql, [record_id, teacher_id], (verifyErr, verifyResults) => {
    if (verifyErr) {
      console.error("❌ Verification Error:", verifyErr);
      return res.status(500).json({ message: "Database error" });
    }

    if (verifyResults.length === 0) {
      return res.status(403).json({ message: "Unauthorized to delete this record" });
    }

    // Delete the record
    const deleteSql = `DELETE FROM attendance_records WHERE id = ?`;

    db.query(deleteSql, [record_id], (deleteErr, result) => {
      if (deleteErr) {
        console.error("❌ Delete Error:", deleteErr);
        return res.status(500).json({ message: "Failed to delete", error: deleteErr });
      }

      console.log(`✅ Attendance record ${record_id} deleted`);

      res.status(200).json({
        message: "Attendance record deleted successfully"
      });
    });
  });
});

console.log("✅ All attendance endpoints initialized");



// ================= ADMIN MONITORING & MANAGEMENT ENDPOINTS =================
// ============================================================================
// ADMIN MONITORING & MANAGEMENT ENDPOINTS - FINAL CORRECTED VERSION
// Based on actual database schema - NO created_at in teacher/student tables
// ============================================================================

console.log('✅ Starting Admin Monitoring endpoints initialization...');

// ============================================================================
// 1. GET ADMIN DASHBOARD STATISTICS
// ============================================================================
app.post("/admin/get-dashboard", (req, res) => {
  const { admin_id } = req.body;

  console.log('📊 Loading admin dashboard for admin:', admin_id);

  if (!admin_id) {
    return res.status(400).json({ message: "Admin ID required" });
  }

  const statsQuery = `
    SELECT 
      (SELECT COUNT(*) FROM teacher_registration) as total_teachers,
      (SELECT COUNT(*) FROM student_registration) as total_students,
      (SELECT COUNT(*) FROM attendance_records) as total_attendance_records,
      (SELECT 
        CASE 
          WHEN COUNT(ar.id) > 0 
          THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
          ELSE 0
        END
       FROM attendance_records ar) as present_percentage
  `;

  db.query(statsQuery, (err, results) => {
    if (err) {
      console.error("❌ Dashboard Error:", err);
      return res.status(500).json({ message: "Failed to load dashboard", error: err });
    }

    console.log("✅ Dashboard loaded successfully");

    res.status(200).json({
      message: "Dashboard loaded successfully",
      statistics: results[0]
    });
  });
});

// ============================================================================
// 2. GET TEACHERS LIST WITH STATISTICS
// ============================================================================
app.post("/admin/get-teachers-list", (req, res) => {
  const { admin_id } = req.body;

  console.log('👥 Loading teachers list for admin:', admin_id);

  if (!admin_id) {
    return res.status(400).json({ message: "Admin ID required" });
  }

  const teachersQuery = `
    SELECT 
      tr.id,
      tr.full_name as name,
      tr.email,
      tr.phone_number,
      tr.profile_image,
      tr.department,
      tr.subject_name,
      COUNT(DISTINCT cs.id) as total_subjects,
      COUNT(DISTINCT se.student_id) as total_students
    FROM teacher_registration tr
    LEFT JOIN class_schedules cs ON tr.id = cs.teacher_id
    LEFT JOIN student_enrollments se ON cs.id = se.schedule_id
    GROUP BY tr.id, tr.full_name, tr.email, tr.phone_number, tr.profile_image, tr.department, tr.subject_name
    ORDER BY tr.full_name
  `;

  db.query(teachersQuery, (err, teachers) => {
    if (err) {
      console.error("❌ Teachers List Error:", err);
      return res.status(500).json({ message: "Failed to load teachers", error: err });
    }

    console.log(`✅ Loaded ${teachers.length} teachers`);

    res.status(200).json({
      message: "Teachers loaded successfully",
      teachers: teachers
    });
  });
});

// ============================================================================
// 3. GET SEMESTER STATISTICS
// ============================================================================
app.post("/admin/get-semester-stats", (req, res) => {
  const { admin_id } = req.body;

  console.log('📚 Loading semester statistics');

  if (!admin_id) {
    return res.status(400).json({ message: "Admin ID required" });
  }

  const semesterQuery = `
    SELECT 
      sr.semester_no,
      COUNT(DISTINCT sr.id) as total_students,
      COUNT(DISTINCT sr.degree) as total_degrees,
      COUNT(DISTINCT CONCAT(sr.degree, '-', sr.section)) as total_sections,
      CASE 
        WHEN COUNT(ar.id) > 0 
        THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
        ELSE 0
      END as avg_attendance
    FROM student_registration sr
    LEFT JOIN attendance_records ar ON sr.id = ar.student_id
    GROUP BY sr.semester_no
    ORDER BY sr.semester_no
  `;

  db.query(semesterQuery, (err, results) => {
    if (err) {
      console.error("❌ Semester Stats Error:", err);
      return res.status(500).json({ message: "Failed to load semester stats", error: err });
    }

    const semesterStats = {};
    results.forEach(row => {
      semesterStats[row.semester_no] = {
        total_students: row.total_students,
        total_degrees: row.total_degrees,
        total_sections: row.total_sections,
        avg_attendance: row.avg_attendance
      };
    });

    console.log(`✅ Loaded stats for ${results.length} semesters`);

    res.status(200).json({
      message: "Semester stats loaded successfully",
      semester_stats: semesterStats
    });
  });
});

// ============================================================================
// 4. GET DEGREE SECTIONS
// ============================================================================
app.post("/admin/get-degree-sections", (req, res) => {
  const { admin_id, semester_no } = req.body;

  console.log(`🎓 Loading degree sections for semester ${semester_no}`);

  if (!admin_id || !semester_no) {
    return res.status(400).json({ message: "Admin ID and Semester number required" });
  }

  const degreeSectionsQuery = `
    SELECT 
      sr.degree,
      sr.section,
      COUNT(DISTINCT sr.id) as student_count,
      CASE 
        WHEN COUNT(ar.id) > 0 
        THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
        ELSE 0
      END as avg_attendance
    FROM student_registration sr
    LEFT JOIN attendance_records ar ON sr.id = ar.student_id
    WHERE sr.semester_no = ?
    GROUP BY sr.degree, sr.section
    ORDER BY sr.degree, sr.section
  `;

  db.query(degreeSectionsQuery, [semester_no], (err, results) => {
    if (err) {
      console.error("❌ Degree Sections Error:", err);
      return res.status(500).json({ message: "Failed to load degree sections", error: err });
    }

    const degreeData = {};
    results.forEach(row => {
      if (!degreeData[row.degree]) {
        degreeData[row.degree] = [];
      }
      degreeData[row.degree].push({
        section: row.section,
        student_count: row.student_count,
        avg_attendance: row.avg_attendance
      });
    });

    console.log(`✅ Loaded sections for ${Object.keys(degreeData).length} degrees`);

    res.status(200).json({
      message: "Degree sections loaded successfully",
      degrees: degreeData
    });
  });
});

// ============================================================================
// 5. GET SECTION STUDENTS
// ============================================================================
app.post("/admin/get-section-students", (req, res) => {
  const { admin_id, degree, section, semester_no } = req.body;

  console.log(`👥 Loading students for ${degree}-${section}, Semester ${semester_no}`);

  if (!admin_id || !degree || !section || !semester_no) {
    return res.status(400).json({ message: "All parameters required" });
  }

  const studentsQuery = `
    SELECT 
      sr.id,
      sr.full_name as name,
      sr.email,
      sr.arid_no,
      sr.phone_number,
      sr.degree,
      sr.section,
      sr.semester_no,
      sr.profile_image,
      COUNT(DISTINCT se.id) as enrolled_courses,
      COUNT(ar.id) as total_classes,
      COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as attended_classes,
      CASE 
        WHEN COUNT(ar.id) > 0 
        THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
        ELSE 0
      END as overall_attendance
    FROM student_registration sr
    LEFT JOIN student_enrollments se ON sr.id = se.student_id
    LEFT JOIN attendance_records ar ON sr.id = ar.student_id
    WHERE sr.degree = ? 
      AND sr.section = ? 
      AND sr.semester_no = ?
    GROUP BY sr.id, sr.full_name, sr.email, sr.arid_no, sr.phone_number, 
             sr.degree, sr.section, sr.semester_no, sr.profile_image
    ORDER BY sr.full_name
  `;

  db.query(studentsQuery, [degree, section, semester_no], (err, students) => {
    if (err) {
      console.error("❌ Section Students Error:", err);
      return res.status(500).json({ message: "Failed to load students", error: err });
    }

    console.log(`✅ Loaded ${students.length} students`);

    res.status(200).json({
      message: "Students loaded successfully",
      students: students
    });
  });
});

// ============================================================================
// 6. GET TEACHER DETAILS
// ============================================================================
app.post("/admin/get-teacher-details", (req, res) => {
  const { admin_id, teacher_id } = req.body;

  console.log(`👨‍🏫 Loading details for teacher ${teacher_id}`);

  if (!admin_id || !teacher_id) {
    return res.status(400).json({ message: "Admin ID and Teacher ID required" });
  }

  // Teacher profile - NO created_at column
  const teacherQuery = `
    SELECT 
      id,
      full_name as name,
      email,
      phone_number,
      profile_image,
      department,
      subject_name,
      shift
    FROM teacher_registration 
    WHERE id = ?
  `;
  
  // Subjects with day_of_week instead of day
  // UPDATED QUERY for subjects - groups properly by subject
const subjectsQuery = `
  SELECT 
    cs.subject_name,
    GROUP_CONCAT(DISTINCT CONCAT(cs.degree, '-', cs.section) ORDER BY cs.section SEPARATOR ', ') as section_list,
    COUNT(DISTINCT se.student_id) as enrolled_students,
    COUNT(DISTINCT ar.date) as classes_conducted,
    COUNT(ar.id) as total_records,
    COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as total_present
  FROM class_schedules cs
  LEFT JOIN student_enrollments se ON cs.id = se.schedule_id
  LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id
  WHERE cs.teacher_id = ?
  GROUP BY cs.subject_name
  ORDER BY cs.subject_name
`;
  
  const activityQuery = `
    SELECT 
      cs.subject_name,
      cs.section,
      ar.date,
      COUNT(ar.id) as students_marked,
      COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as present_count
    FROM attendance_records ar
    JOIN class_schedules cs ON ar.schedule_id = cs.id
    WHERE cs.teacher_id = ?
    GROUP BY ar.date, cs.subject_name, cs.section
    ORDER BY ar.date DESC
    LIMIT 10
  `;
  
  const statsQuery = `
    SELECT 
      COUNT(DISTINCT cs.id) as total_subjects,
      COUNT(DISTINCT se.student_id) as total_students,
      COUNT(DISTINCT ar.date) as total_classes,
      CASE 
        WHEN COUNT(ar.id) > 0 
        THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
        ELSE 0
      END as average_attendance
    FROM class_schedules cs
    LEFT JOIN student_enrollments se ON cs.id = se.schedule_id
    LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id
    WHERE cs.teacher_id = ?
  `;

  db.query(teacherQuery, [teacher_id], (err1, teacher) => {
    if (err1 || teacher.length === 0) {
      console.error("❌ Teacher Query Error:", err1);
      return res.status(404).json({ message: "Teacher not found" });
    }
    
    db.query(subjectsQuery, [teacher_id], (err2, subjects) => {
      db.query(activityQuery, [teacher_id], (err3, activity) => {
        db.query(statsQuery, [teacher_id], (err4, stats) => {
          if (err2 || err3 || err4) {
            console.error("❌ Details Query Error:", err2 || err3 || err4);
            return res.status(500).json({ message: "Error loading details" });
          }

          console.log("✅ Teacher details loaded successfully");
          
          res.status(200).json({
            message: "Teacher details loaded successfully",
            teacher: teacher[0],
            subjects: subjects,
            recent_activity: activity,
            statistics: stats[0]
          });
        });
      });
    });
  });
});

// ============================================================================
// 7. GET STUDENT DETAILS
// ============================================================================
app.post("/admin/get-student-details", (req, res) => {
  const { admin_id, student_id } = req.body;

  console.log(`🎓 Loading details for student ${student_id}`);

  if (!admin_id || !student_id) {
    return res.status(400).json({ message: "Admin ID and Student ID required" });
  }

  // Student profile - NO created_at column
  const studentQuery = `
    SELECT 
      id,
      full_name as name,
      email,
      arid_no,
      phone_number,
      degree,
      section,
      semester_no,
      profile_image
    FROM student_registration 
    WHERE id = ?
  `;
  
  const coursesQuery = `
    SELECT 
      se.id as enrollment_id,
      cs.id as schedule_id,
      cs.subject_name,
      cs.day_of_week,
      cs.start_time,
      cs.end_time,
      tr.full_name as teacher_name,
      COUNT(ar.id) as total_classes,
      COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as attended_classes,
      CASE 
        WHEN COUNT(ar.id) > 0 
        THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
        ELSE 0
      END as attendance_percentage
    FROM student_enrollments se
    JOIN class_schedules cs ON se.schedule_id = cs.id
    LEFT JOIN teacher_registration tr ON cs.teacher_id = tr.id
    LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id AND ar.student_id = ?
    WHERE se.student_id = ?
    GROUP BY se.id, cs.id, cs.subject_name, cs.day_of_week, cs.start_time, cs.end_time, tr.full_name
    ORDER BY cs.subject_name
  `;
  
  const attendanceQuery = `
    SELECT 
      ar.id,
      cs.subject_name,
      ar.status,
      ar.date,
      ar.time,
      tr.full_name as teacher_name
    FROM attendance_records ar
    JOIN class_schedules cs ON ar.schedule_id = cs.id
    LEFT JOIN teacher_registration tr ON cs.teacher_id = tr.id
    WHERE ar.student_id = ?
    ORDER BY ar.date DESC, ar.time DESC
    LIMIT 20
  `;
  
  const statsQuery = `
    SELECT 
      COUNT(DISTINCT se.id) as total_courses,
      COUNT(ar.id) as total_classes,
      COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as total_attended,
      CASE 
        WHEN COUNT(ar.id) > 0 
        THEN ROUND(((COUNT(CASE WHEN ar.status = 'present' THEN 1 END) / COUNT(ar.id)) * 100), 2)
        ELSE 0
      END as overall_attendance
    FROM student_enrollments se
    LEFT JOIN attendance_records ar ON ar.student_id = ?
    WHERE se.student_id = ?
  `;

  db.query(studentQuery, [student_id], (err1, student) => {
    if (err1 || student.length === 0) {
      console.error("❌ Student Query Error:", err1);
      return res.status(404).json({ message: "Student not found" });
    }
    
    db.query(coursesQuery, [student_id, student_id], (err2, courses) => {
      db.query(attendanceQuery, [student_id], (err3, attendance) => {
        db.query(statsQuery, [student_id, student_id], (err4, stats) => {
          if (err2 || err3 || err4) {
            console.error("❌ Details Query Error:", err2 || err3 || err4);
            return res.status(500).json({ message: "Error loading details" });
          }

          console.log("✅ Student details loaded successfully");
          
          res.status(200).json({
            message: "Student details loaded successfully",
            student: student[0],
            courses: courses,
            recent_attendance: attendance,
            statistics: stats[0]
          });
        });
      });
    });
  });
});

// ============================================================================
// 8. ADD ATTENDANCE
// ============================================================================
app.post("/admin/add-attendance", (req, res) => {
  const { admin_id, student_id, schedule_id, date, status } = req.body;

  console.log(`✏️ Admin adding attendance: student ${student_id}, schedule ${schedule_id}, ${status}, ${date}`);

  if (!admin_id || !student_id || !schedule_id || !date || !status) {
    return res.status(400).json({ message: "All fields are required" });
  }

  // Check if attendance already exists
  const checkQuery = `
    SELECT * FROM attendance_records 
    WHERE schedule_id = ? AND student_id = ? AND date = ?
  `;

  db.query(checkQuery, [schedule_id, student_id, date], (err, existing) => {
    if (err) {
      console.error("❌ Check Error:", err);
      return res.status(500).json({ message: "Error checking attendance", error: err });
    }

    if (existing.length > 0) {
      return res.status(400).json({ 
        message: "Attendance already marked for this student on this date" 
      });
    }

    // Get student name and teacher_id from schedule
    const detailsQuery = `
      SELECT 
        sr.full_name as student_name,
        cs.teacher_id
      FROM student_registration sr, class_schedules cs
      WHERE sr.id = ? AND cs.id = ?
    `;

    db.query(detailsQuery, [student_id, schedule_id], (err2, details) => {
      if (err2 || details.length === 0) {
        console.error("❌ Details Query Error:", err2);
        return res.status(500).json({ message: "Invalid student or schedule ID" });
      }

      const insertQuery = `
        INSERT INTO attendance_records 
        (student_id, student_name, schedule_id, teacher_id, date, time, status, marked_by, created_at)
        VALUES (?, ?, ?, ?, ?, CURTIME(), ?, 'teacher', NOW())
      `;

      db.query(
        insertQuery, 
        [student_id, details[0].student_name, schedule_id, details[0].teacher_id, date, status], 
        (err3, result) => {
          if (err3) {
            console.error("❌ Insert Error:", err3);
            return res.status(500).json({ message: "Failed to add attendance", error: err3 });
          }

          console.log("✅ Attendance added successfully");

          res.status(201).json({
            message: "Attendance added successfully",
            attendance_id: result.insertId
          });
        }
      );
    });
  });
});

// ============================================================================
// 9. EDIT ATTENDANCE
// ============================================================================
app.post("/admin/edit-attendance", (req, res) => {
  const { admin_id, attendance_id, status } = req.body;

  console.log(`✏️ Admin editing attendance: ${attendance_id} to ${status}`);

  if (!admin_id || !attendance_id || !status) {
    return res.status(400).json({ message: "All fields are required" });
  }

  const updateQuery = `
    UPDATE attendance_records 
    SET status = ?, updated_at = NOW()
    WHERE id = ?
  `;

  db.query(updateQuery, [status, attendance_id], (err, result) => {
    if (err) {
      console.error("❌ Update Error:", err);
      return res.status(500).json({ message: "Failed to update attendance", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Attendance record not found" });
    }

    console.log("✅ Attendance updated successfully");

    res.status(200).json({
      message: "Attendance updated successfully"
    });
  });
});

// ============================================================================
// 10. DELETE ATTENDANCE
// ============================================================================
app.post("/admin/delete-attendance", (req, res) => {
  const { admin_id, attendance_id } = req.body;

  console.log(`🗑️ Admin deleting attendance: ${attendance_id}`);

  if (!admin_id || !attendance_id) {
    return res.status(400).json({ message: "Admin ID and Attendance ID required" });
  }

  const deleteQuery = `DELETE FROM attendance_records WHERE id = ?`;

  db.query(deleteQuery, [attendance_id], (err, result) => {
    if (err) {
      console.error("❌ Delete Error:", err);
      return res.status(500).json({ message: "Failed to delete attendance", error: err });
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Attendance record not found" });
    }

    console.log("✅ Attendance deleted successfully");

    res.status(200).json({
      message: "Attendance deleted successfully"
    });
  });
});

// ============================================================================
// 11. GET RECENT ACTIVITY
// ============================================================================
app.post("/admin/get-recent-activity", (req, res) => {
  const { admin_id, limit } = req.body;

  console.log('🔄 Fetching recent activity for admin:', admin_id);

  if (!admin_id) {
    return res.status(400).json({ message: "Admin ID required" });
  }

  const activityLimit = limit || 20;

  const activitySql = `
    SELECT 
      'attendance' as activity_type,
      ar.student_name as actor,
      CONCAT('Attendance marked ', ar.status, ' for ', cs.subject_name) as description,
      ar.created_at as timestamp
    FROM attendance_records ar
    JOIN class_schedules cs ON ar.schedule_id = cs.id
    ORDER BY ar.created_at DESC
    LIMIT ?
  `;

  db.query(activitySql, [activityLimit], (err, activities) => {
    if (err) {
      console.error("❌ Activity Error:", err);
      return res.status(500).json({ message: "Failed to fetch activity", error: err });
    }

    console.log(`✅ Found ${activities.length} recent activities`);

    res.status(200).json({
      message: "Recent activity retrieved successfully",
      activities: activities
    });
  });
});

// ============================================================================
// SEARCH ENDPOINTS
// ============================================================================

app.post("/admin/search-teachers", (req, res) => {
  const { admin_id, search_query } = req.body;

  if (!admin_id || !search_query) {
    return res.status(400).json({ message: "Admin ID and search query required" });
  }

  const searchSql = `
    SELECT 
      id,
      full_name as name,
      email,
      phone_number,
      department,
      subject_name
    FROM teacher_registration
    WHERE full_name LIKE ? OR email LIKE ? OR department LIKE ?
    ORDER BY full_name
    LIMIT 50
  `;

  const searchTerm = `%${search_query}%`;

  db.query(searchSql, [searchTerm, searchTerm, searchTerm], (err, results) => {
    if (err) {
      console.error("❌ Search Error:", err);
      return res.status(500).json({ message: "Search failed", error: err });
    }

    res.status(200).json({
      message: "Search completed successfully",
      teachers: results,
      count: results.length
    });
  });
});

app.post("/admin/search-students", (req, res) => {
  const { admin_id, search_query } = req.body;

  if (!admin_id || !search_query) {
    return res.status(400).json({ message: "Admin ID and search query required" });
  }

  const searchSql = `
    SELECT 
      id,
      full_name as name,
      arid_no,
      email,
      degree,
      semester_no,
      section
    FROM student_registration
    WHERE full_name LIKE ? OR arid_no LIKE ? OR email LIKE ?
    ORDER BY full_name
    LIMIT 50
  `;

  const searchTerm = `%${search_query}%`;

  db.query(searchSql, [searchTerm, searchTerm, searchTerm], (err, results) => {
    if (err) {
      console.error("❌ Search Error:", err);
      return res.status(500).json({ message: "Search failed", error: err });
    }

    res.status(200).json({
      message: "Search completed successfully",
      students: results,
      count: results.length
    });
  });
});

// ============================================================================
// OLD ENDPOINTS (For backward compatibility)
// ============================================================================

app.post("/teacher/get-details", (req, res) => {
  const { teacher_id } = req.body;

  console.log(`👨‍🏫 Fetching teacher details: ${teacher_id}`);

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID required" });
  }

  const teacherQuery = `
    SELECT 
      id,
      full_name as name,
      email,
      phone_number,
      profile_image
    FROM teacher_registration
    WHERE id = ?
  `;

  db.query(teacherQuery, [teacher_id], (err, results) => {
    if (err) {
      console.error("❌ Teacher Error:", err);
      return res.status(500).json({ message: "Failed to fetch teacher", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Teacher not found" });
    }

    console.log("✅ Teacher details fetched successfully");

    res.status(200).json({
      message: "Teacher details retrieved successfully",
      teacher: results[0]
    });
  });
});

app.post("/teacher/get-profile", (req, res) => {
  const { teacher_id } = req.body;

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID required" });
  }

  const profileQuery = `
    SELECT 
      id,
      full_name,
      email,
      phone_number,
      profile_image,
      department,
      subject_name,
      shift
    FROM teacher_registration
    WHERE id = ?
  `;

  db.query(profileQuery, [teacher_id], (err, results) => {
    if (err) {
      console.error("❌ Profile Error:", err);
      return res.status(500).json({ message: "Failed to fetch profile", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Teacher not found" });
    }

    res.status(200).json({
      message: "Profile retrieved successfully",
      teacher: results[0]
    });
  });
});

app.post("/student/get-details", (req, res) => {
  const { student_id } = req.body;

  console.log(`👨‍🎓 Fetching student details: ${student_id}`);

  if (!student_id) {
    return res.status(400).json({ message: "Student ID required" });
  }

  const studentQuery = `
    SELECT 
      id,
      full_name as name,
      email,
      arid_no,
      phone_number,
      degree,
      section,
      semester_no,
      profile_image
    FROM student_registration
    WHERE id = ?
  `;

  db.query(studentQuery, [student_id], (err, results) => {
    if (err) {
      console.error("❌ Student Error:", err);
      return res.status(500).json({ message: "Failed to fetch student", error: err });
    }

    if (results.length === 0) {
      return res.status(404).json({ message: "Student not found" });
    }

    console.log("✅ Student details fetched successfully");

    res.status(200).json({
      message: "Student details retrieved successfully",
      student: results[0]
    });
  });
});

console.log("✅ All Admin Monitoring endpoints initialized successfully");

//------------------------------------------------------------------------------------





// ============================================
// FACE RECOGNITION ENDPOINTS FOR FLUTTER
// Add these to the end of your server.js file
// ============================================

// Helper: Calculate Euclidean distance between two face descriptors
function euclideanDistance(descriptor1, descriptor2) {
  if (descriptor1.length !== descriptor2.length) {
    throw new Error('Descriptors must have the same length');
  }
  
  let sum = 0;
  for (let i = 0; i < descriptor1.length; i++) {
    const diff = descriptor1[i] - descriptor2[i];
    sum += diff * diff;
  }
  
  return Math.sqrt(sum);
}

// Helper: Compare two face descriptors and return similarity percentage
function compareFaceDescriptors(descriptor1, descriptor2) {
  try {
    const distance = euclideanDistance(descriptor1, descriptor2);
    // Convert distance to similarity percentage (0-100)
    // Typical face descriptor distance ranges from 0 to ~1.5
    const similarity = Math.max(0, Math.min(100, (1 - distance) * 100));
    return {
      similarity: similarity,
      distance: distance,
      isMatch: distance < 0.6 // Threshold for face match
    };
  } catch (error) {
    console.error('Error comparing faces:', error);
    return {
      similarity: 0,
      distance: 999,
      isMatch: false
    };
  }
}

// ============================================
// ENDPOINT 1: Register/Update Student Face
// ============================================
app.post("/register-student-face", async (req, res) => {
  try {
    const { student_id, face_descriptor, face_image_base64 } = req.body;
    
    console.log('📸 Face registration request for student:', student_id);
    
    if (!student_id || !face_descriptor) {
      return res.status(400).json({ 
        success: false,
        message: "Student ID and face descriptor required" 
      });
    }

    // Parse face descriptor
    let descriptorArray;
    try {
      descriptorArray = typeof face_descriptor === 'string' 
        ? JSON.parse(face_descriptor) 
        : face_descriptor;
    } catch (e) {
      return res.status(400).json({ 
        success: false,
        message: "Invalid face descriptor format" 
      });
    }

    // Validate descriptor
    if (!Array.isArray(descriptorArray) || descriptorArray.length === 0) {
      return res.status(400).json({ 
        success: false,
        message: "Face descriptor must be a non-empty array" 
      });
    }

    const descriptorJSON = JSON.stringify(descriptorArray);
    const imagePath = face_image_base64 || null; // Store base64 directly

    // Check if face data already exists
    const checkSql = `SELECT id FROM student_face_data WHERE student_id = ?`;
    
    db.query(checkSql, [student_id], (checkErr, checkResults) => {
      if (checkErr) {
        console.error("❌ Database error:", checkErr);
        return res.status(500).json({ 
          success: false,
          message: "Database error" 
        });
      }

      if (checkResults.length > 0) {
        // Update existing face data
        const updateSql = `
          UPDATE student_face_data 
          SET face_encoding = ?, 
              face_image_path = ?, 
              updated_at = NOW()
          WHERE student_id = ?
        `;
        
        db.query(updateSql, [descriptorJSON, imagePath, student_id], (updateErr) => {
          if (updateErr) {
            console.error("❌ Update error:", updateErr);
            return res.status(500).json({ 
              success: false,
              message: "Failed to update face data" 
            });
          }

          console.log(`✅ Face data updated for student ${student_id}`);
          res.status(200).json({ 
            success: true,
            message: "Face updated successfully",
            face_registered: true
          });
        });
      } else {
        // Insert new face data
        const insertSql = `
          INSERT INTO student_face_data (student_id, face_encoding, face_image_path)
          VALUES (?, ?, ?)
        `;
        
        db.query(insertSql, [student_id, descriptorJSON, imagePath], (insertErr) => {
          if (insertErr) {
            console.error("❌ Insert error:", insertErr);
            return res.status(500).json({ 
              success: false,
              message: "Failed to register face" 
            });
          }

          console.log(`✅ Face registered for student ${student_id}`);
          res.status(201).json({ 
            success: true,
            message: "Face registered successfully",
            face_registered: true
          });
        });
      }
    });
  } catch (error) {
    console.error("❌ Face registration error:", error);
    res.status(500).json({ 
      success: false,
      message: "Failed to process face data", 
      error: error.message 
    });
  }
});

// ============================================
// ENDPOINT 2: Check if Student Has Face Registered
// ============================================
app.post("/check-face-registered", (req, res) => {
  const { student_id } = req.body;

  console.log('🔍 Checking face registration for student:', student_id);

  if (!student_id) {
    return res.status(400).json({ 
      success: false,
      message: "Student ID required" 
    });
  }

  const sql = `SELECT id, face_image_path, created_at FROM student_face_data WHERE student_id = ?`;
  
  db.query(sql, [student_id], (err, results) => {
    if (err) {
      console.error("❌ Database error:", err);
      return res.status(500).json({ 
        success: false,
        message: "Database error" 
      });
    }

    const isRegistered = results.length > 0;
    console.log(`✅ Face registration status for student ${student_id}: ${isRegistered}`);

    res.status(200).json({
      success: true,
      face_registered: isRegistered,
      has_image: isRegistered && results[0].face_image_path,
      registration_date: isRegistered ? results[0].created_at : null
    });
  });
});

// ============================================
// ENDPOINT 3: Mark Face Attendance
// ============================================
app.post("/mark-face-attendance", async (req, res) => {
  try {
    const { student_id, student_name, schedule_id, face_descriptor } = req.body;

    console.log('👤 Face attendance request for student:', student_id);

    if (!student_id || !student_name || !schedule_id || !face_descriptor) {
      return res.status(400).json({ 
        success: false,
        message: "All fields required: student_id, student_name, schedule_id, face_descriptor" 
      });
    }

    // Parse uploaded face descriptor
    let uploadedDescriptor;
    try {
      uploadedDescriptor = typeof face_descriptor === 'string' 
        ? JSON.parse(face_descriptor) 
        : face_descriptor;
    } catch (e) {
      return res.status(400).json({ 
        success: false,
        message: "Invalid face descriptor format" 
      });
    }

    const today = new Date().toISOString().split('T')[0];
    const now = new Date().toTimeString().split(' ')[0];

    // Get stored face descriptor from database
    const getFaceSql = `SELECT face_encoding FROM student_face_data WHERE student_id = ?`;
    
    db.query(getFaceSql, [student_id], async (faceErr, faceResults) => {
      if (faceErr) {
        console.error("❌ Database error:", faceErr);
        return res.status(500).json({ 
          success: false,
          message: "Database error" 
        });
      }

      if (faceResults.length === 0) {
        return res.status(400).json({ 
          success: false,
          message: "No face registered. Please register your face first.",
          needs_registration: true
        });
      }

      // Parse stored descriptor
      let storedDescriptor;
      try {
        storedDescriptor = JSON.parse(faceResults[0].face_encoding);
      } catch (e) {
        return res.status(500).json({ 
          success: false,
          message: "Invalid stored face data. Please re-register your face." 
        });
      }

      // Compare face descriptors
      const comparison = compareFaceDescriptors(storedDescriptor, uploadedDescriptor);
      
      console.log(`📊 Face match - Distance: ${comparison.distance.toFixed(3)}, Similarity: ${comparison.similarity.toFixed(2)}%`);

      // Check if faces match (adjustable threshold)
      const MATCH_THRESHOLD = 85; // 50% similarity required
      
      if (comparison.similarity < MATCH_THRESHOLD) {
        return res.status(400).json({
          success: false,
          message: `Face verification failed. Match: ${comparison.similarity.toFixed(1)}% (Required: ${MATCH_THRESHOLD}%)`,
          similarity: comparison.similarity.toFixed(1),
          distance: comparison.distance.toFixed(3),
          face_match: false
        });
      }

      // Check if attendance already marked today
      const checkSql = `
        SELECT id FROM attendance_records
        WHERE student_id = ? AND schedule_id = ? AND date = ?
        LIMIT 1
      `;

      db.query(checkSql, [student_id, schedule_id, today], (checkErr, checkResults) => {
        if (checkErr) {
          console.error("❌ Check error:", checkErr);
          return res.status(500).json({ 
            success: false,
            message: "Database error" 
          });
        }

        if (checkResults.length > 0) {
          return res.status(400).json({ 
            success: false,
            message: "Attendance already marked for today",
            already_marked: true
          });
        }

        // Mark attendance
        const insertSql = `
          INSERT INTO attendance_records
          (student_id, student_name, schedule_id, date, time, status, marked_by, face_similarity)
          VALUES (?, ?, ?, ?, ?, 'present', 'face', ?)
        `;

        db.query(
          insertSql,
          [student_id, student_name, schedule_id, today, now, comparison.similarity.toFixed(2)],
          (insertErr, result) => {
            if (insertErr) {
              console.error("❌ Insert error:", insertErr);
              return res.status(500).json({ 
                success: false,
                message: "Failed to mark attendance" 
              });
            }

            console.log(`✅ Face attendance marked for student ${student_id} (${comparison.similarity.toFixed(2)}% match)`);

            res.status(201).json({
              success: true,
              message: "Attendance marked successfully via face recognition",
              attendance_id: result.insertId,
              similarity: comparison.similarity.toFixed(1),
              distance: comparison.distance.toFixed(3),
              face_match: true
            });
          }
        );
      });
    });
  } catch (error) {
    console.error("❌ Face attendance error:", error);
    res.status(500).json({ 
      success: false,
      message: "Failed to process face attendance", 
      error: error.message 
    });
  }
});

// ============================================
// ENDPOINT 4: Get Face Registration Status with Image
// ============================================
app.post("/get-face-data", (req, res) => {
  const { student_id } = req.body;

  if (!student_id) {
    return res.status(400).json({ 
      success: false,
      message: "Student ID required" 
    });
  }

  const sql = `
    SELECT 
      id,
      face_image_path,
      created_at,
      updated_at
    FROM student_face_data 
    WHERE student_id = ?
  `;
  
  db.query(sql, [student_id], (err, results) => {
    if (err) {
      console.error("❌ Database error:", err);
      return res.status(500).json({ 
        success: false,
        message: "Database error" 
      });
    }

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No face data found for this student"
      });
    }

    res.status(200).json({
      success: true,
      face_image: results[0].face_image_path,
      registered_at: results[0].created_at,
      updated_at: results[0].updated_at
    });
  });
});

// ============================================
// ENDPOINT 5: Delete Student Face Data
// ============================================
app.post("/delete-face-data", (req, res) => {
  const { student_id } = req.body;

  console.log('🗑️ Deleting face data for student:', student_id);

  if (!student_id) {
    return res.status(400).json({ 
      success: false,
      message: "Student ID required" 
    });
  }

  const deleteSql = `DELETE FROM student_face_data WHERE student_id = ?`;
  
  db.query(deleteSql, [student_id], (deleteErr, deleteResult) => {
    if (deleteErr) {
      console.error("❌ Delete error:", deleteErr);
      return res.status(500).json({ 
        success: false,
        message: "Failed to delete face data" 
      });
    }

    if (deleteResult.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "No face data found to delete"
      });
    }

    console.log(`✅ Face data deleted for student ${student_id}`);

    res.status(200).json({
      success: true,
      message: "Face data deleted successfully",
      rows_affected: deleteResult.affectedRows
    });
  });
});

console.log("✅ Face recognition endpoints initialized");

// ================= GET STUDENT ATTENDANCE STATISTICS =================
app.post("/get-student-attendance-stats", (req, res) => {
  const { student_id } = req.body;

  console.log("📊 Fetching attendance stats for Student ID:", student_id);

  if (!student_id) {
    return res.status(400).json({ message: "Student ID is required" });
  }

  try {
    // Get all subjects the student is enrolled in with attendance data
    const subjectsSql = `
      SELECT 
        cs.id as schedule_id,
        cs.subject_name as course_name,
        cs.teacher_name,
        COUNT(DISTINCT CASE WHEN ar.status = 'present' THEN ar.id END) as attended_classes,
        COUNT(DISTINCT ar.id) as total_classes
      FROM class_schedules cs
      INNER JOIN student_enrollments se ON cs.id = se.schedule_id
      LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id AND ar.student_id = ?
      WHERE se.student_id = ?
      GROUP BY cs.id, cs.subject_name, cs.teacher_name
      ORDER BY cs.subject_name
    `;

    db.query(subjectsSql, [student_id, student_id], (err, subjects) => {
      if (err) {
        console.error("❌ Database Error (subjects):", err);
        return res.status(500).json({ message: "Database error", error: err.message });
      }

      console.log(`✅ Found ${subjects.length} enrolled subjects`);

      // Calculate overall statistics
      let totalPresent = 0;
      let totalClasses = 0;

      const subjectsWithPercentage = subjects.map(subject => {
        const attended = subject.attended_classes || 0;
        const total = subject.total_classes || 0;
        
        totalPresent += attended;
        totalClasses += total;

        return {
          schedule_id: subject.schedule_id,
          course_name: subject.course_name,
          teacher_name: subject.teacher_name,
          attended_classes: attended,
          total_classes: total,
          percentage: total > 0 ? ((attended / total) * 100).toFixed(1) : 0
        };
      });

      const overallPercentage = totalClasses > 0 
        ? ((totalPresent / totalClasses) * 100).toFixed(1)
        : 0;

      const totalAbsent = totalClasses - totalPresent;

      console.log("📊 Stats Summary:");
      console.log(`   Total Classes: ${totalClasses}`);
      console.log(`   Total Present: ${totalPresent}`);
      console.log(`   Total Absent: ${totalAbsent}`);
      console.log(`   Overall Percentage: ${overallPercentage}%`);

      res.status(200).json({
        message: "Attendance statistics retrieved successfully",
        overall_percentage: parseFloat(overallPercentage),
        total_present: totalPresent,
        total_absent: totalAbsent,
        total_classes: totalClasses,
        subjects: subjectsWithPercentage,
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});


// ================= GET TEACHER STATISTICS (COMPLETE FIXED VERSION) =================
app.post("/get-teacher-statistics", (req, res) => {
  const { teacher_id } = req.body;

  console.log("📊 Fetching statistics for Teacher ID:", teacher_id);

  if (!teacher_id) {
    return res.status(400).json({ message: "Teacher ID is required" });
  }

  try {
    // ✅ FIXED: Count DISTINCT subject_name instead of schedule IDs
    const overallSql = `
      SELECT 
        COUNT(DISTINCT cs.subject_name) as total_subjects,
        COUNT(DISTINCT CONCAT(cs.degree, '-', cs.section, '-', cs.semester_no)) as total_sections,
        COUNT(DISTINCT se.student_id) as total_students,
        COUNT(DISTINCT ar.id) as total_classes
      FROM class_schedules cs
      LEFT JOIN student_enrollments se ON cs.id = se.schedule_id
      LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id
      WHERE cs.teacher_id = ?
    `;

    db.query(overallSql, [teacher_id], (err, overallResults) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err.message });
      }

      const overall = overallResults[0];
      console.log("📊 Overall Stats:", {
        subjects: overall.total_subjects,
        sections: overall.total_sections,
        students: overall.total_students,
        classes: overall.total_classes
      });

      // Get average attendance across all classes
      const avgAttendanceSql = `
        SELECT 
          COALESCE(
            AVG(
              CASE 
                WHEN total_classes > 0 
                THEN (present_count * 100.0 / total_classes) 
                ELSE 0 
              END
            ),
            0
          ) as avg_attendance
        FROM (
          SELECT 
            cs.id,
            COUNT(DISTINCT ar.id) as total_classes,
            COUNT(DISTINCT CASE WHEN ar.status = 'present' THEN ar.id END) as present_count
          FROM class_schedules cs
          LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id
          WHERE cs.teacher_id = ?
          GROUP BY cs.id
        ) as class_stats
      `;

      db.query(avgAttendanceSql, [teacher_id], (err2, avgResults) => {
        if (err2) {
          console.error("❌ Avg Attendance Error:", err2);
          return res.status(500).json({ message: "Database error", error: err2.message });
        }

        // ✅ FIXED: Safe handling of avg_attendance with null check
        const avgAttendanceRaw = avgResults[0]?.avg_attendance;
        const avgAttendance = (avgAttendanceRaw !== null && avgAttendanceRaw !== undefined) 
          ? parseFloat(Number(avgAttendanceRaw).toFixed(1)) 
          : 0.0;

        console.log("📊 Average Attendance:", avgAttendance);

        // ✅ FIXED: Group by subject_name to get stats per SUBJECT (not per schedule)
        const subjectsSql = `
          SELECT 
            cs.subject_name,
            COUNT(DISTINCT cs.id) as total_schedules,
            COUNT(DISTINCT CONCAT(cs.degree, '-', cs.section)) as total_sections,
            COUNT(DISTINCT se.student_id) as total_students,
            COUNT(DISTINCT ar.id) as classes_taken,
            COALESCE(
              AVG(
                CASE 
                  WHEN total_by_schedule > 0 
                  THEN (present_by_schedule * 100.0 / total_by_schedule)
                  ELSE 0 
                END
              ),
              0
            ) as avg_attendance
          FROM class_schedules cs
          LEFT JOIN student_enrollments se ON cs.id = se.schedule_id
          LEFT JOIN attendance_records ar ON cs.id = ar.schedule_id
          LEFT JOIN (
            SELECT 
              schedule_id,
              COUNT(*) as total_by_schedule,
              COUNT(CASE WHEN status = 'present' THEN 1 END) as present_by_schedule
            FROM attendance_records
            GROUP BY schedule_id
          ) ar_stats ON cs.id = ar_stats.schedule_id
          WHERE cs.teacher_id = ?
          GROUP BY cs.subject_name
          ORDER BY cs.subject_name
        `;

        db.query(subjectsSql, [teacher_id], (err3, subjects) => {
          if (err3) {
            console.error("❌ Subjects Error:", err3);
            return res.status(500).json({ message: "Database error", error: err3.message });
          }

          console.log("📊 Subjects Found:", subjects.length);
          if (subjects.length > 0) {
            subjects.forEach(s => {
              console.log(`   - ${s.subject_name}: ${s.total_sections} sections, ${s.total_students} students`);
            });
          }

          // ✅ FIXED: Process subjects with safe null handling
          const processedSubjects = subjects.map(s => {
            const subjectAvgRaw = s.avg_attendance;
            const subjectAvg = (subjectAvgRaw !== null && subjectAvgRaw !== undefined)
              ? parseFloat(Number(subjectAvgRaw).toFixed(1))
              : 0.0;

            return {
              subject_name: s.subject_name,
              total_sections: s.total_sections || 0,
              total_students: s.total_students || 0,
              classes_taken: s.classes_taken || 0,
              avg_attendance: subjectAvg
            };
          });

          console.log("✅ Teacher statistics retrieved successfully");

          res.status(200).json({
            message: "Teacher statistics retrieved successfully",
            total_subjects: overall.total_subjects || 0,
            total_sections: overall.total_sections || 0,
            total_students: overall.total_students || 0,
            total_classes: overall.total_classes || 0,
            avg_attendance: avgAttendance,
            subjects: processedSubjects,
          });
        });
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});


// ================= GET ADMIN STATISTICS (COMPLETE VERSION) =================
app.post("/get-admin-statistics", (req, res) => {
  const { admin_id } = req.body;

  console.log("📊 Fetching statistics for Admin ID:", admin_id);

  if (!admin_id) {
    return res.status(400).json({ message: "Admin ID is required" });
  }

  try {
    // Get overall statistics
    const overallSql = `
      SELECT 
        (SELECT COUNT(*) FROM \`teacher_registration\`) as total_teachers,
        (SELECT COUNT(*) FROM \`student_registration\`) as total_students,
        (SELECT COUNT(DISTINCT subject_name) FROM \`class_schedules\`) as total_subjects,
        (SELECT COUNT(DISTINCT CONCAT(degree, '-', section)) FROM \`class_schedules\`) as total_sections,
        (SELECT COUNT(*) FROM \`attendance_records\`) as total_attendance_records,
        (SELECT COUNT(*) FROM \`attendance_records\` WHERE status = 'present') as total_present,
        (SELECT COUNT(*) FROM \`attendance_records\` WHERE status = 'absent') as total_absent,
        (SELECT COUNT(*) FROM \`complaints\`) as total_complaints,
        (SELECT COUNT(*) FROM \`complaints\` WHERE status = 'pending') as pending_complaints,
        (SELECT COUNT(*) FROM \`complaints\` WHERE status = 'in_progress') as in_progress_complaints,
        (SELECT COUNT(*) FROM \`complaints\` WHERE status = 'resolved') as resolved_complaints
    `;

    db.query(overallSql, (err, overallResults) => {
      if (err) {
        console.error("❌ Database Error:", err);
        return res.status(500).json({ message: "Database error", error: err.message });
      }

      const overall = overallResults[0];
      
      // Calculate present percentage safely
      const totalRecords = overall.total_attendance_records || 0;
      const totalPresent = overall.total_present || 0;
      const presentPercentage = totalRecords > 0 
        ? parseFloat((totalPresent / totalRecords * 100).toFixed(1))
        : 0.0;

      console.log("📊 Overall Stats:", {
        teachers: overall.total_teachers,
        students: overall.total_students,
        subjects: overall.total_subjects,
        sections: overall.total_sections,
        records: overall.total_attendance_records,
        presentPercentage: presentPercentage
      });

      // Get department-wise statistics
      const departmentSql = `
        SELECT 
          cs.teacher_department as department,
          COUNT(DISTINCT cs.teacher_id) as total_teachers,
          COUNT(DISTINCT se.student_id) as total_students,
          COUNT(DISTINCT cs.subject_name) as total_subjects,
          COUNT(DISTINCT CONCAT(cs.degree, '-', cs.section)) as total_sections,
          COUNT(DISTINCT ar.id) as total_classes,
          COALESCE(
            AVG(
              CASE 
                WHEN total_by_dept > 0 
                THEN (present_by_dept * 100.0 / total_by_dept)
                ELSE 0 
              END
            ),
            0
          ) as avg_attendance
        FROM \`class_schedules\` cs
        LEFT JOIN \`student_enrollments\` se ON cs.id = se.schedule_id
        LEFT JOIN \`attendance_records\` ar ON cs.id = ar.schedule_id
        LEFT JOIN (
          SELECT 
            cs2.teacher_department,
            COUNT(*) as total_by_dept,
            COUNT(CASE WHEN ar2.status = 'present' THEN 1 END) as present_by_dept
          FROM \`class_schedules\` cs2
          LEFT JOIN \`attendance_records\` ar2 ON cs2.id = ar2.schedule_id
          GROUP BY cs2.teacher_department
        ) dept_stats ON cs.teacher_department = dept_stats.teacher_department
        WHERE cs.teacher_department IS NOT NULL AND cs.teacher_department != ''
        GROUP BY cs.teacher_department
        ORDER BY cs.teacher_department
      `;

      db.query(departmentSql, (err2, departments) => {
        if (err2) {
          console.error("❌ Department Error:", err2);
          departments = [];
        }

        console.log("📊 Departments Found:", departments.length);

        // Process departments with safe null handling
        const processedDepartments = departments.map(d => {
          const deptAvgRaw = d.avg_attendance;
          const deptAvg = (deptAvgRaw !== null && deptAvgRaw !== undefined)
            ? parseFloat(Number(deptAvgRaw).toFixed(1))
            : 0.0;

          return {
            department: d.department,
            total_teachers: d.total_teachers || 0,
            total_students: d.total_students || 0,
            total_subjects: d.total_subjects || 0,
            total_sections: d.total_sections || 0,
            total_classes: d.total_classes || 0,
            avg_attendance: deptAvg
          };
        });

        // Get recent enrollments (last 30 days) - FIXED: Use enrolled_at instead of created_at
        const recentEnrollmentsSql = `
          SELECT 
            DATE(enrolled_at) as enrollment_date,
            COUNT(*) as count
          FROM \`student_enrollments\`
          WHERE enrolled_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
          GROUP BY DATE(enrolled_at)
          ORDER BY enrollment_date DESC
          LIMIT 7
        `;

        db.query(recentEnrollmentsSql, (err3, enrollments) => {
          if (err3) {
            console.error("❌ Enrollments Error:", err3);
            enrollments = [];
          }

          // Check if attendance_records has a timestamp column
          // First, let's try with a simple query to get column info
          const checkColumnSql = `
            SELECT COLUMN_NAME 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'attendance_records' 
            AND COLUMN_NAME IN ('created_at', 'timestamp', 'attendance_date', 'marked_at')
          `;

          db.query(checkColumnSql, (err4, columns) => {
            let attendanceTrends = [];
            
            // If we found a timestamp column, use it
            if (!err4 && columns && columns.length > 0) {
              const timestampColumn = columns[0].COLUMN_NAME;
              
              const attendanceTrendsSql = `
                SELECT 
                  DATE(${timestampColumn}) as attendance_date,
                  COUNT(*) as total_records,
                  COUNT(CASE WHEN status = 'present' THEN 1 END) as present_count,
                  COALESCE(
                    (COUNT(CASE WHEN status = 'present' THEN 1 END) * 100.0 / COUNT(*)),
                    0
                  ) as present_percentage
                FROM \`attendance_records\`
                WHERE ${timestampColumn} >= DATE_SUB(NOW(), INTERVAL 7 DAY)
                GROUP BY DATE(${timestampColumn})
                ORDER BY attendance_date DESC
              `;

              db.query(attendanceTrendsSql, (err5, trends) => {
                if (!err5 && trends) {
                  attendanceTrends = trends.map(t => ({
                    date: t.attendance_date,
                    total_records: t.total_records || 0,
                    present_count: t.present_count || 0,
                    present_percentage: t.present_percentage 
                      ? parseFloat(Number(t.present_percentage).toFixed(1))
                      : 0.0
                  }));
                }

                sendResponse();
              });
            } else {
              // No timestamp column found, send response without trends
              sendResponse();
            }

            function sendResponse() {
              console.log("✅ Admin statistics retrieved successfully");

              res.status(200).json({
                message: "Admin statistics retrieved successfully",
                total_teachers: overall.total_teachers || 0,
                total_students: overall.total_students || 0,
                total_subjects: overall.total_subjects || 0,
                total_sections: overall.total_sections || 0,
                total_attendance_records: overall.total_attendance_records || 0,
                total_present: overall.total_present || 0,
                total_absent: overall.total_absent || 0,
                present_percentage: presentPercentage,
                total_complaints: overall.total_complaints || 0,
                pending_complaints: overall.pending_complaints || 0,
                in_progress_complaints: overall.in_progress_complaints || 0,
                resolved_complaints: overall.resolved_complaints || 0,
                departments: processedDepartments,
                recent_enrollments: enrollments || [],
                attendance_trends: attendanceTrends || [],
              });
            }
          });
        });
      });
    });
  } catch (error) {
    console.error("❌ Server Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});


// ================= ENHANCED CHATBOT SERVER CODE =================
// Complete with NLP, role-based questions, human-like conversation

// ========== COMPLETE CHATBOT SYSTEM WITH ROLE-BASED RESPONSES ==========
// Place this AFTER db connection and BEFORE app.listen()

// ========== NLP & UTILITIES ==========

// Levenshtein Distance for typo tolerance
function levenshteinDistance(str1, str2) {
  const matrix = [];
  
  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }
  
  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }
  
  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1
        );
      }
    }
  }
  
  return matrix[str2.length][str1.length];
}

// Word stemming for better matching
function getWordStem(word) {
  const suffixes = ['ing', 'ed', 'ly', 's'];
  let stem = word.toLowerCase();
  
  for (const suffix of suffixes) {
    if (stem.endsWith(suffix)) {
      return stem.substring(0, stem.length - suffix.length);
    }
  }
  
  return stem;
}

// Calculate word similarity
function wordSimilarity(word1, word2) {
  const distance = levenshteinDistance(word1, word2);
  const maxLen = Math.max(word1.length, word2.length);
  return 1 - (distance / maxLen);
}

// Extract key words from message (remove stop words)
function extractKeywords(message) {
  const stopWords = new Set([
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
    'can', 'could', 'should', 'may', 'might', 'must', 'shall',
    'my', 'your', 'his', 'her', 'its', 'our', 'their',
    'and', 'but', 'or', 'if', 'because', 'as', 'until', 'while',
    'please', 'thank', 'thanks', 'okay', 'ok', 'sure', 'yes', 'no',
    'what', 'when', 'where', 'who', 'why', 'how', 'which',
  ]);
  
  const words = message.toLowerCase().split(/\s+/);
  return words.filter(w => !stopWords.has(w) && w.length > 2);
}

// Load synonyms from database
let synonymCache = {};
let lastSynonymLoad = 0;

async function loadSynonyms() {
  const now = Date.now();
  if (now - lastSynonymLoad < 600000 && Object.keys(synonymCache).length > 0) {
    return synonymCache;
  }
  
  return new Promise((resolve, reject) => {
    db.query('SELECT * FROM chatbot_synonyms WHERE is_active = 1', (err, results) => {
      if (err) {
        console.error('❌ Error loading synonyms:', err);
        reject(err);
        return;
      }
      
      synonymCache = {};
      results.forEach(row => {
        const synonymList = row.synonyms.split(',').map(s => s.trim().toLowerCase());
        synonymCache[row.word.toLowerCase()] = {
          synonyms: synonymList,
          category: row.category
        };
        
        synonymList.forEach(syn => {
          if (!synonymCache[syn]) {
            synonymCache[syn] = {
              mainWord: row.word.toLowerCase(),
              category: row.category
            };
          }
        });
      });
      
      lastSynonymLoad = now;
      console.log(`✅ Loaded ${Object.keys(synonymCache).length} synonym entries`);
      resolve(synonymCache);
    });
  });
}

// Expand message with synonyms
async function expandWithSynonyms(message) {
  await loadSynonyms();
  
  const words = message.toLowerCase().split(/\s+/);
  const expandedWords = new Set(words);
  
  words.forEach(word => {
    const synData = synonymCache[word];
    if (synData) {
      if (synData.synonyms) {
        synData.synonyms.forEach(syn => expandedWords.add(syn));
        expandedWords.add(word);
      } else if (synData.mainWord) {
        expandedWords.add(synData.mainWord);
        const mainSynData = synonymCache[synData.mainWord];
        if (mainSynData && mainSynData.synonyms) {
          mainSynData.synonyms.forEach(syn => expandedWords.add(syn));
        }
      }
    }
  });
  
  return Array.from(expandedWords).join(' ');
}

// Extract entities (day, time, teacher, subject)
function extractEntities(message, userContext) {
   const entities = {};
  const lowerMessage = message.toLowerCase();
  
  // Extract day
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  const dayAliases = {
    'mon': 'monday', 'tue': 'tuesday', 'wed': 'wednesday',
    'thu': 'thursday', 'fri': 'friday', 'sat': 'saturday', 'sun': 'sunday',
    'tomorrow': getTomorrow(), 
    'today': getToday(),
    'kal': getTomorrow(), // Urdu for tomorrow
    'aaj': getToday(), // Urdu for today
    'peer': 'monday', 'mangal': 'tuesday', 'budh': 'wednesday',
    'jumerat': 'thursday', 'juma': 'friday', 'jumma': 'friday',
    'hafta': 'saturday', 'itwaar': 'sunday'
  };
  
  days.forEach(day => {
    if (lowerMessage.includes(day)) {
      entities.day = day.charAt(0).toUpperCase() + day.slice(1);
    }
  });
  
  Object.keys(dayAliases).forEach(alias => {
    if (lowerMessage.includes(alias)) {
      const day = dayAliases[alias];
      entities.day = day.charAt(0).toUpperCase() + day.slice(1);
    }
  });
  
  // Check if message specifically asks for tomorrow
  if (/tomorrow|kal|next day/.test(lowerMessage)) {
    entities.isTomorrow = true;
  }
  
  // Extract time (existing code)
  const timePattern = /\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?\b/g;
  let timeMatch;
  while ((timeMatch = timePattern.exec(message)) !== null) {
    let hour = parseInt(timeMatch[1]);
    const minute = timeMatch[2] || '00';
    const meridiem = timeMatch[3] ? timeMatch[3].toLowerCase() : null;
    
    if (meridiem === 'pm' && hour < 12) {
      hour += 12;
    } else if (meridiem === 'am' && hour === 12) {
      hour = 0;
    }
    
    if (!meridiem && hour >= 1 && hour <= 7) {
      hour += 12;
    }
    
    entities.time = `${hour.toString().padStart(2, '0')}:${minute}:00`;
    entities.displayTime = `${timeMatch[1]}:${minute}${meridiem ? ' ' + meridiem.toUpperCase() : ''}`;
  }
  
  // Extract teacher name (existing code)
  const teacherPattern = /(Dr\.|Prof\.|Mr\.|Ms\.|Miss|Sir|Ma'am)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/gi;
  const teacherMatch = message.match(teacherPattern);
  if (teacherMatch) {
    entities.teacher = teacherMatch[0].trim();
  }
  
  // Extract subject (expanded list)
  const subjectKeywords = [
    'math', 'maths', 'mathematics', 'calculus', 'algebra',
    'english', 'urdu', 
    'science', 'physics', 'chemistry', 'biology',
    'history', 'geography', 'islamiat', 'pakistan studies',
    'computer', 'programming', 'coding', 'software', 'database',
    'java', 'python', 'c++', 'javascript', 'web',
    'networking', 'data structure', 'algorithm',
    'agriculture', 'agronomy', 'horticulture',
    'veterinary', 'animal science',
    'statistics', 'economics', 'business'
  ];
  
  const words = lowerMessage.split(/\s+/);
  for (const keyword of subjectKeywords) {
    if (words.some(w => w.includes(keyword))) {
      entities.subject = keyword;
      break;
    }
  }
  
  return entities;
}

function getToday() {
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  return days[new Date().getDay()];
}

function getTomorrow() {
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const today = new Date().getDay();
  return days[(today + 1) % 7];
}

// Detect mental health concerns
function detectMentalHealthConcern(message) {
  const lowerMessage = message.toLowerCase();
  
  const concernKeywords = {
    depression: ['depressed', 'depression', 'sad', 'hopeless', 'empty', 'worthless', 'udaas', 'ghum', 'pareshaan'],
    anxiety: ['anxious', 'anxiety', 'worried', 'panic', 'stressed', 'overwhelmed', 'ghbrana', 'takleef'],
    crisis: ['suicide', 'kill myself', 'end it all', 'hurt myself', 'marna chahta', 'khatam kar du'],
    advice: ['advice', 'help', 'suggest', 'mujhe batao', 'kya karu', 'kaise karu', 'guidance', 'mushkil'],
  };
  
  for (const [type, keywords] of Object.entries(concernKeywords)) {
    if (keywords.some(keyword => lowerMessage.includes(keyword))) {
      return type;
    }
  }
  
  return null;
}

// ========== NORMALIZE INPUT FUNCTION ==========
// Handles case insensitivity and special characters
function normalizeInput(message) {
  return message
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ')           // Multiple spaces → single space
    .replace(/[!?\.]+$/g, '')        // Remove trailing punctuation
    .replace(/^[!?\s]+/g, '')        // Remove leading punctuation
    .replace(/[,;:]/g, '');           // Remove mid-sentence special chars
}


// Detect greeting & casual questions
// Detect greeting & casual questions
function detectCasualQuestion(message) {
  const normalized = normalizeInput(message);  // USE NORMALIZED INPUT
  
  // Greetings with various spellings
  if (/^(hi|hey|hello|helo|hii|heya|yo|sup|salam|assalam|assalaam|kya haal|kaise ho|how are you|what's up|whats up|howdy|namaste)/.test(normalized)) {
    return 'greeting';
  }
  
  // User info variations
  if (/what.*my.*name|mera naam|mere naam kya hai|who am i|meri jankari|my info|my profile|my details|about me/.test(normalized)) {
    return 'user_info';
  }
  
  // How are you variations
  if (/how are you|kaise ho|how you doing|you okay|tum theek|how is it going|whats up with you|how have you been/.test(normalized)) {
    return 'casual_greeting';
  }
  
  // Developer/creator questions
  if (/who (made|created|developed|built) (this|the) (app|application|chatbot|bot)|developer|development team|creator|kis ne banaya/.test(normalized)) {
    return 'developers_info';
  }
  
  return null;
}

// Intent recognition with improved NLP
// Intent recognition with improved NLP
async function recognizeIntent(message, entities) {
  const MIN_CONFIDENCE = 0.4;  // Minimum confidence threshold
  
  return new Promise((resolve, reject) => {
    db.query(
      'SELECT * FROM chatbot_intents WHERE is_active = 1 ORDER BY priority DESC',
      async (err, intents) => {
        if (err) {
          reject(err);
          return;
        }
        
        const expandedMessage = await expandWithSynonyms(message);
        const lowerMessage = message.toLowerCase().trim();
        const expandedLower = expandedMessage.toLowerCase().trim();
        const keywords = extractKeywords(message);
        
        let bestMatch = {
          intent: 'unknown',
          confidence: 0,
          matchedPattern: null
        };
        
        for (const intent of intents) {
          const patterns = intent.patterns.split(',').map(p => p.trim().toLowerCase());
          let maxScore = 0;
          let matchedPattern = null;
          
          for (const pattern of patterns) {
            let score = 0;
            
            if (lowerMessage === pattern || expandedLower === pattern) {
              score = 1.0;
              matchedPattern = pattern;
            }
            else if (lowerMessage.includes(pattern) || expandedLower.includes(pattern)) {
              score = 0.95;
              matchedPattern = pattern;
            }
            else {
              const patternWords = pattern.split(/\s+/);
              const messageWords = lowerMessage.split(/\s+/);
              const expandedWords = expandedLower.split(/\s+/);
              
              const matchedInMessage = patternWords.filter(pw => {
                const pwStem = getWordStem(pw);
                return messageWords.some(mw => {
                  const mwStem = getWordStem(mw);
                  return pwStem === mwStem || wordSimilarity(pwStem, mwStem) > 0.8;
                }) || expandedWords.includes(pw);
              });
              
              if (matchedInMessage.length > 0) {
                const matchRatio = matchedInMessage.length / patternWords.length;
                
                if (matchRatio >= 0.8) {
                  score = 0.85;
                  matchedPattern = pattern;
                } else if (matchRatio >= 0.6) {
                  score = 0.65;
                  matchedPattern = pattern;
                } else if (matchRatio >= 0.4) {
                  score = matchRatio * 0.5;
                }
              }
            }
            
            if (score > maxScore) {
              maxScore = score;
              matchedPattern = pattern;
            }
          }
          
          if (intent.requires_entities && maxScore > 0) {
            const required = intent.requires_entities.split(',').map(e => e.trim());
            const hasAllRequired = required.every(req => entities[req]);
            
            if (!hasAllRequired) {
              maxScore *= 0.3;
            }
          }
          
          if (maxScore > 0) {
            const priorityBoost = Math.min(0.1, intent.priority * 0.01);
            maxScore = Math.min(0.99, maxScore + priorityBoost);
          }
          
          // NEW: Apply minimum confidence threshold
          if (maxScore >= MIN_CONFIDENCE && maxScore > bestMatch.confidence) {
            bestMatch = {
              intent: intent.intent_name,
              confidence: maxScore,
              matchedPattern: matchedPattern,
              requiresEntities: intent.requires_entities
            };
          }
        }
        
        // NEW: If no intent meets minimum threshold, return unknown
        if (bestMatch.confidence < MIN_CONFIDENCE) {
          bestMatch.intent = 'unknown';
          bestMatch.confidence = 0;
        }
        
        resolve(bestMatch);
      }
    );
  });
}


// ========== ROLE-BASED HANDLERS ==========

// Greeting Handler
function handleGreeting(session) {
  const isStudent = session.user_role === 'Student';
  const greetings = isStudent ? [
    `Hey ${session.user_name}! 👋 How can I help you today?`,
    `Hi ${session.user_name}! What can I do for you?`,
    `Hello! Nice to see you again, ${session.user_name}. Need help with your schedule?`,
    `Salam ${session.user_name}! 👋 Kya main aapki madad kar sakta hun?`,
  ] : [
    `Good day ${session.user_name}! 👋 How may I assist you?`,
    `Hello Professor/Sir! What would you like to know?`,
    `Salam ${session.user_name}! Ready to help with your schedule.`,
  ];
  
  return greetings[Math.floor(Math.random() * greetings.length)];
}

// User Info Handler
function handleUserInfo(session) {
  const isStudent = session.user_role === 'Student';
  
  let info = `📋 **Your Information:**\n\n`;
  info += `👤 Name: ${session.user_name}\n`;
  info += `🔑 ID: ${session.user_id}\n`;
  info += `👨 Role: ${session.user_role}\n`;
  
  if (isStudent) {
    if (session.user_degree) info += `📚 Degree: ${session.user_degree}\n`;
    if (session.user_section) info += `📍 Section: ${session.user_section}\n`;
    if (session.user_semester) info += `📊 Semester: ${session.user_semester}\n`;
  } else {
    if (session.user_department) info += `🏢 Department: ${session.user_department}\n`;
  }
  
  return info;
}

// Casual Greeting Handler
function handleCasualGreeting(session) {
  const isStudent = session.user_role === 'Student';
  const responses = isStudent ? [
    `I'm doing great, thanks for asking! 😊 How can I help you?`,
    `I'm here and ready to help! What do you need?`,
    `All good! How about you? What brings you here?`,
    `Bilkul theek hoon! Aap bataye, kya madad chahiye?`,
  ] : [
    `I'm functioning perfectly, thank you! How may I assist you today?`,
    `All systems operational! What information do you need?`,
    `Excellent, thank you! What can I help you with?`,
  ];
  
  return responses[Math.floor(Math.random() * responses.length)];
}

// Mental Health Concern Handler
function handleMentalHealthConcern(concernType, session) {
  const responses = {
    depression: `I'm sorry you're feeling down. Please remember:\n\n💙 You're not alone\n🏥 Campus Counseling Center is available\n📞 24/7 Support Hotline available\n\nPlease reach out to someone you trust. Your feelings matter. 💙`,
    anxiety: `I understand you're feeling stressed. Try these:\n\n🌬️ Deep breathing exercises\n🚶 Take a short walk\n💬 Talk to someone\n📞 Counseling services available\n\nWould you like help with something specific?`,
    crisis: `Please reach out for help RIGHT NOW:\n\n🚨 Emergency: 911\n📞 Crisis Hotline: Available 24/7\n💙 Counseling: Campus Center\n\nYour life is important. Please talk to someone immediately.`,
    advice: `I'm happy to help! What specific advice do you need?\n\n📚 Academic guidance\n💼 Career advice\n😟 Personal matters\n📅 Schedule planning\n\nTell me more!`,
  };
  
  return responses[concernType] || responses.crisis;
}


async function handleMyScheduleTomorrow(session, entities) {
  if (session.user_role !== 'Student') {
    return handleTeacherScheduleTomorrow(session);
  }

  return new Promise((resolve, reject) => {
    // Get tomorrow’s date safely
    const today = new Date();
    const tomorrowDate = new Date(today);
    tomorrowDate.setDate(today.getDate() + 1);

    // Get proper weekday name for tomorrow
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const tomorrow = days[tomorrowDate.getDay()];

    console.log(`🗓 Fetching schedule for tomorrow: ${tomorrow}`);

    const sql = `
      SELECT * FROM class_schedules 
      WHERE degree = ? AND section = ? AND semester_no = ?
        AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;

    db.query(
      sql,
      [session.user_degree, session.user_section, session.user_semester, tomorrow],
      (err, results) => {
        if (err) {
          reject(err);
          return;
        }

        if (results.length === 0) {
          resolve(`🎉 You have no classes tomorrow (${tomorrow})! Enjoy your free day!`);
          return;
        }

        let response = `📅 **Your Schedule for Tomorrow (${tomorrow}):**\n\n`;

        results.forEach((cls, index) => {
          const startTime = cls.start_time?.substring(0, 5) || 'TBA';
          const endTime = cls.end_time?.substring(0, 5) || 'TBA';
          
          response += `${index + 1}. **${cls.subject_name}**\n`;
          response += `   ⏰ ${startTime} - ${endTime}\n`;
          response += `   👨‍🏫 ${cls.teacher_name || 'TBA'}\n`;
          response += `   📍 ${cls.room_number || 'TBA'}\n\n`;
        });

        resolve(response.trim());
      }
    );
  });
}

async function handleTeacherScheduleTomorrow(session) {
  return new Promise((resolve, reject) => {
    // Get tomorrow’s real date and weekday
    const today = new Date();
    const tomorrowDate = new Date(today);
    tomorrowDate.setDate(today.getDate() + 1);

    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const tomorrow = days[tomorrowDate.getDay()];

    console.log(`🧑‍🏫 Fetching teacher schedule for tomorrow: ${tomorrow}`);

    const sql = `
      SELECT * FROM class_schedules 
      WHERE teacher_id = ? AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;

    db.query(sql, [session.user_id, tomorrow], (err, results) => {
      if (err) {
        reject(err);
        return;
      }

      if (results.length === 0) {
        resolve(`✅ You have no classes scheduled for tomorrow (${tomorrow}).`);
        return;
      }

      let response = `📅 **Your Teaching Schedule for Tomorrow (${tomorrow}):**\n\n`;

      results.forEach((cls, index) => {
        const startTime = cls.start_time?.substring(0, 5) || 'TBA';
        const endTime = cls.end_time?.substring(0, 5) || 'TBA';
        const classLabel = cls.class_code || `${cls.degree || ''}-${cls.section || ''}`.trim();

        response += `${index + 1}. **${cls.subject_name}**\n`;
        response += `   ⏰ ${startTime} - ${endTime}\n`;
        response += `   👥 Class: ${classLabel || 'TBA'}\n`;
        response += `   📍 ${cls.room_number || 'TBA'}\n\n`;
      });

      resolve(response.trim());
    });
  });
}

// TEACHER SCHEDULE - TODAY
async function handleTeacherScheduleToday(session) {
  return new Promise((resolve, reject) => {
    // Get today's weekday name
    const todayDate = new Date();
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const today = days[todayDate.getDay()];

    console.log(`🧑‍🏫 Fetching teacher schedule for today: ${today}`);

    const sql = `
      SELECT * FROM class_schedules 
      WHERE teacher_id = ? AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;

    db.query(sql, [session.user_id, today], (err, results) => {
      if (err) {
        reject(err);
        return;
      }

      if (results.length === 0) {
        resolve(`✅ You have no classes scheduled for today (${today}).`);
        return;
      }

      let response = `📅 **Your Teaching Schedule for Today (${today}):**\n\n`;

      results.forEach((cls, index) => {
        const startTime = cls.start_time?.substring(0, 5) || 'TBA';
        const endTime = cls.end_time?.substring(0, 5) || 'TBA';
        const classLabel =
          cls.class_code || `${cls.degree || ''}-${cls.section || ''}`.trim();

        response += `${index + 1}. **${cls.subject_name}**\n`;
        response += `   ⏰ ${startTime} - ${endTime}\n`;
        response += `   👥 Class: ${classLabel || 'TBA'}\n`;
        response += `   📍 ${cls.room_number || 'TBA'}\n\n`;
      });

      resolve(response.trim());
    });
  });
}

// SCHEDULE FOR SPECIFIC DAY
async function handleMyScheduleDay(session, entities) {
  if (!entities.day) {
    return "Which day would you like to check? (Monday, Tuesday, etc.)";
  }
  
  if (session.user_role !== 'Student') {
    return handleTeacherScheduleDay(session, entities.day);
  }
  
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT * FROM class_schedules 
      WHERE degree = ? AND section = ? AND semester_no = ?
        AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;
    
    db.query(
      sql,
      [session.user_degree, session.user_section, session.user_semester, entities.day],
      (err, results) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (results.length === 0) {
          resolve(`🎉 You have no classes on ${entities.day}!`);
          return;
        }
        
        let response = `📅 **Your Schedule for ${entities.day}:**\n\n`;
        
        results.forEach((cls, index) => {
          const startTime = cls.start_time.substring(0, 5);
          const endTime = cls.end_time.substring(0, 5);
          
          response += `${index + 1}. **${cls.subject_name}**\n`;
          response += `   ⏰ ${startTime} - ${endTime}\n`;
          response += `   👨‍🏫 ${cls.teacher_name || 'TBA'}\n`;
          response += `   📍 ${cls.room_number || 'TBA'}\n\n`;
        });
        
        resolve(response.trim());
      }
    );
  });
}

// TEACHER SCHEDULE - SPECIFIC DAY
async function handleTeacherScheduleDay(session, day) {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT * FROM class_schedules 
      WHERE teacher_id = ? AND day_of_week = ? AND is_active = 1
      ORDER BY start_time ASC
    `;
    
    db.query(sql, [session.user_id, day], (err, results) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (results.length === 0) {
        resolve(`✅ You have no classes scheduled for ${day}.`);
        return;
      }
      
      let response = `📅 **Your Teaching Schedule for ${day}:**\n\n`;
      
      results.forEach((cls, index) => {
        const startTime = cls.start_time.substring(0, 5);
        const endTime = cls.end_time.substring(0, 5);
        
        response += `${index + 1}. **${cls.subject_name}**\n`;
        response += `   ⏰ ${startTime} - ${endTime}\n`;
        response += `   👥 Class: ${cls.class_code}\n`;
        response += `   📍 ${cls.room_number || 'TBA'}\n\n`;
      });
      
      resolve(response.trim());
    });
  });
}

// NEXT CLASS - STUDENT ONLY
async function handleMyNextClass(session, entities) {
  if (session.user_role !== 'Student') {
    return handleTeacherNextClass(session);
  }
  
  return new Promise((resolve, reject) => {
    const today = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][new Date().getDay()];
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:00`;
    
    const sql = `
      SELECT * FROM class_schedules 
      WHERE degree = ? AND section = ? AND semester_no = ?
        AND day_of_week = ? AND start_time > ? AND is_active = 1
      ORDER BY start_time ASC LIMIT 1
    `;
    
    db.query(
      sql,
      [session.user_degree, session.user_section, session.user_semester, today, currentTime],
      (err, results) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (results.length === 0) {
          resolve("🎉 No more classes today! You're done for the day!");
          return;
        }
        
        const nextClass = results[0];
        const startTime = nextClass.start_time.substring(0, 5);
        const endTime = nextClass.end_time.substring(0, 5);
        
        const response = `📖 **Your Next Class:**\n\n` +
          `📚 ${nextClass.subject_name}\n` +
          `⏰ ${startTime} - ${endTime}\n` +
          `👨‍🏫 ${nextClass.teacher_name || 'TBA'}\n` +
          `📍 ${nextClass.room_number || 'TBA'}`;
        
        resolve(response);
      }
    );
  });
}

// TEACHER NEXT CLASS
async function handleTeacherNextClass(session) {
  return new Promise((resolve, reject) => {
    const today = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][new Date().getDay()];
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:00`;
    
    const sql = `
      SELECT * FROM class_schedules 
      WHERE teacher_id = ? AND day_of_week = ? AND start_time > ? AND is_active = 1
      ORDER BY start_time ASC LIMIT 1
    `;
    
    db.query(sql, [session.user_id, today, currentTime], (err, results) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (results.length === 0) {
        resolve("✅ No more classes scheduled for today.");
        return;
      }
      
      const nextClass = results[0];
      const startTime = nextClass.start_time.substring(0, 5);
      const endTime = nextClass.end_time.substring(0, 5);
      
      const response = `📖 **Your Next Class:**\n\n` +
        `📚 ${nextClass.subject_name}\n` +
        `⏰ ${startTime} - ${endTime}\n` +
        `👥 Class: ${nextClass.class_code || nextClass.degree + '-' + nextClass.section}\n` +
        `📍 ${nextClass.room_number || 'TBA'}`;
      
      resolve(response);
    });
  });
}

// CLASS AT SPECIFIC TIME - STUDENT ONLY
async function handleClassAtTime(session, entities) {
  if (!entities.time) {
    return "What time are you checking for? (e.g., 2 PM, 14:00)";
  }
  
  if (session.user_role !== 'Student') {
    return "This feature is primarily for students. Teachers can check their full schedule.";
  }
  
  return new Promise((resolve, reject) => {
    const today = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][new Date().getDay()];
    
    const sql = `
      SELECT * FROM class_schedules 
      WHERE degree = ? AND section = ? AND semester_no = ?
        AND day_of_week = ? 
        AND start_time <= ? AND end_time >= ?
        AND is_active = 1
    `;
    
    db.query(
      sql,
      [session.user_degree, session.user_section, session.user_semester, today, entities.time, entities.time],
      (err, results) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (results.length === 0) {
          resolve(`✅ You're free at ${entities.displayTime}!`);
          return;
        }
        
        const cls = results[0];
        const startTime = cls.start_time.substring(0, 5);
        const endTime = cls.end_time.substring(0, 5);
        
        const response = `❌ You have a class at ${entities.displayTime}:\n\n` +
          `📚 ${cls.subject_name}\n` +
          `⏰ ${startTime} - ${endTime}\n` +
          `👨‍🏫 ${cls.teacher_name || 'TBA'}\n` +
          `📍 ${cls.room_number || 'TBA'}`;
        
        resolve(response);
      }
    );
  });
}

// ========== TEACHER INFO HANDLER ==========

// ====================== TEACHER INFO HANDLER ======================
async function handleTeacherInfo(session, entities, message) {
  return new Promise((resolve, reject) => {
    try {
      const lowerMessage = message.toLowerCase();

      // ========== 1. Check for teacher entity + email/contact request ==========
      if (entities.teacher && (lowerMessage.includes('email') || lowerMessage.includes('contact'))) {
        const namePart = entities.teacher.replace(/^(Dr\.|Prof\.|Mr\.|Ms\.|Miss|Sir|Ma'am)\s+/i, '').trim();

        const sql = `
          SELECT full_name, email, department 
          FROM teacher_registration
          WHERE LOWER(full_name) LIKE ? AND is_active = 1
          LIMIT 5
        `;

        db.query(sql, [`%${namePart.toLowerCase()}%`], (err, results) => {
          if (err) return reject(err);

          if (!results || results.length === 0) {
            return resolve(`❌ Couldn't find "${entities.teacher}" in the system.`);
          }

          // Single match
          if (results.length === 1) {
            const teacher = results[0];
            let response = `👨‍🏫 **${teacher.full_name}**`;
            if (teacher.email) response += `\n📧 ${teacher.email}`;
            if (teacher.department) response += `\n🏢 ${teacher.department}`;
            return resolve(response);
          }

          // Multiple matches
          let response = `Found multiple teachers matching "${entities.teacher}":\n\n`;
          results.forEach((t, i) => {
            response += `${i + 1}. ${t.full_name}${t.department ? ' - ' + t.department : ''}`;
            if (t.email) response += ` | 📧 ${t.email}`;
            response += `\n`;
          });
          response += `\nPlease specify the full name for more accurate results.`;
          return resolve(response);
        });

        return; // exit early
      }

      // ========== 2. Search by subject ==========
      const words = lowerMessage.split(/\s+/);
      const stopWords = ['who', 'teaches', 'is', 'the', 'teacher', 'of', 'for', 'what', 'kon', 'parhata'];
      const searchQuery = words.filter(w => !stopWords.includes(w) && w.length > 2).join(' ');

      if (!searchQuery) {
        return resolve("Which subject or teacher would you like to know about?");
      }

      const sqlSubject = `
        SELECT DISTINCT teacher_name, subject_name, teacher_id
        FROM class_schedules 
        WHERE LOWER(subject_name) LIKE ? AND is_active = 1 AND teacher_name IS NOT NULL
        LIMIT 5
      `;

      db.query(sqlSubject, [`%${searchQuery}%`], (err, results) => {
        if (err) return reject(err);

        if (!results || results.length === 0) {
          return resolve(`❌ Couldn't find teacher information for "${searchQuery}".`);
        }

        // Single result
        if (results.length === 1) {
          const cls = results[0];
          db.query(
            'SELECT email FROM teacher_registration WHERE id = ?',
            [cls.teacher_id],
            (err2, teacherData) => {
              let response = `👨‍🏫 **${cls.subject_name}** is taught by **${cls.teacher_name}**`;
              if (!err2 && teacherData?.[0]?.email) {
                response += `\n📧 ${teacherData[0].email}`;
              }
              return resolve(response);
            }
          );
        } else {
          // Multiple results
          let response = `Found multiple results matching "${searchQuery}":\n\n`;
          results.forEach((t, i) => {
            response += `${i + 1}. ${t.subject_name} - ${t.teacher_name}\n`;
          });
          return resolve(response);
        }
      });
    } catch (error) {
      reject(error);
    }
  });
}

// ========== COMPLAINTS HANDLER - USER SPECIFIC ==========

async function handleMyComplaints(session) {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT * FROM complaints 
      WHERE reported_by_id = ? AND reported_by_role = ? AND is_active = 1
      ORDER BY created_at DESC LIMIT 10
    `;
    
    db.query(sql, [session.user_id, session.user_role], (err, results) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (results.length === 0) {
        resolve("📋 You haven't filed any complaints yet.\n\nTo file a complaint, please use the Complaints section in the app.");
        return;
      }
      
      const isStudent = session.user_role === 'Student';
      let response = `📋 **Your Complaints** (${results.length} total):\n\n`;
      
      results.forEach((c, i) => {
        const statusEmoji = c.status === 'pending' ? '⏳' : c.status === 'in_progress' ? '🔧' : '✅';
        response += `${i + 1}. ${statusEmoji} **${c.title}**\n`;
        response += `   📍 Location: ${c.location}\n`;
        response += `   📊 Status: ${c.status.replace('_', ' ')}\n`;
        response += `   📅 Filed: ${new Date(c.created_at).toLocaleDateString()}\n\n`;
      });
      
      if (isStudent) {
        response += `\n💡 Want to check a specific complaint status?`;
      }
      
      resolve(response.trim());
    });
  });
}

// ========== ANNOUNCEMENTS HANDLER - ROLE BASED ==========

async function handleMyAnnouncements(session) {
  return new Promise((resolve, reject) => {
    const audienceType = session.user_role === 'Student' ? 'students' : 'teachers';
    
    const sql = `
      SELECT * FROM announcements 
      WHERE (target_role = 'all' OR target_role = ?) 
        AND is_active = 1
        AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      ORDER BY created_at DESC LIMIT 5
    `;
    
    db.query(sql, [audienceType], (err, results) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (results.length === 0) {
        resolve("📢 No recent announcements in the last 7 days.");
        return;
      }
      
      const isStudent = session.user_role === 'Student';
      let response = `📢 **Recent Announcements** (Last 7 days):\n\n`;
      
      results.forEach((a, i) => {
        const emoji = a.category === 'urgent' ? '🔴' : a.category === 'important' ? '🟡' : '🔵';
        response += `${i + 1}. ${emoji} **${a.title}**\n`;
        response += `   ${a.description.substring(0, 80)}${a.description.length > 80 ? '...' : ''}\n`;
        response += `   📅 ${new Date(a.created_at).toLocaleDateString()}\n\n`;
      });
      
      if (isStudent) {
        response += `\n💡 Check the Announcements section for full details!`;
      }
      
      resolve(response.trim());
    });
  });
}

// UNREAD ANNOUNCEMENTS - USER SPECIFIC
async function handleUnreadAnnouncements(session) {
  return new Promise((resolve, reject) => {
    const audienceType = session.user_role === 'Student' ? 'students' : 'teachers';
    
    const sql = `
      SELECT a.* FROM announcements a
      LEFT JOIN announcement_reads ar ON a.id = ar.announcement_id 
        AND ar.user_id = ? AND ar.user_role = ?
      WHERE ar.id IS NULL
        AND (a.target_role = 'all' OR a.target_role = ?)
        AND a.is_active = 1
        AND a.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      ORDER BY a.created_at DESC LIMIT 5
    `;
    
    db.query(sql, [session.user_id, session.user_role, audienceType], (err, results) => {
      if (err) {
        reject(err);
        return;
      }
      
      if (results.length === 0) {
        resolve("✅ No new unread announcements! You're all caught up. 🎉");
        return;
      }
      
      let response = `📢 **You have ${results.length} unread announcement${results.length > 1 ? 's' : ''}:**\n\n`;
      
      results.forEach((a, i) => {
        const emoji = a.category === 'urgent' ? '🔴' : a.category === 'important' ? '🟡' : '🔵';
        response += `${i + 1}. ${emoji} **${a.title}**\n`;
        response += `   ${a.description.substring(0, 70)}${a.description.length > 70 ? '...' : ''}\n`;
        response += `   📅 ${new Date(a.created_at).toLocaleDateString()}\n\n`;
      });
      
      resolve(response.trim());
    });
  });
}


// ========== ADMISSIONS INFO - ROLE BASED ==========
async function handleAdmissionsInfo(session) {
  const isStudent = session.user_role === 'Student';
  let response = `📋 **Admission Information**\n\n`;

  if (isStudent) {
    response += `🎓 **Already enrolled? Great!**\n\nIf you know someone interested in admissions:\n\n`;
  }

  response += `🎓 **Undergraduate Programs:**\n` +
    `   • BS Programs in various disciplines\n` +
    `   • Eligibility: FSc/A-Level or equivalent\n\n` +
    `📚 **Graduate Programs:**\n` +
    `   • MS/M.Phil Programs\n` +
    `   • PhD Programs\n` +
    `   • Eligibility: Relevant Bachelor's/Master's degree\n\n` +
    `📅 **Admission Schedule:**\n` +
    `   • Fall Semester: August-September\n` +
    `   • Spring Semester: January-February\n\n` +
    `📞 **For Details:**\n` +
    `   • Visit university website\n` +
    `   • Contact Admissions Office\n` +
    `   • Check announcements for deadlines`;

  return response;
}



// ========== CAMPUS FACILITIES - SAME FOR ALL ==========
async function getResponseFromDatabase(intentName, session) {
  return new Promise((resolve) => {
    const sql = `
      SELECT response FROM chatbot_responses 
      WHERE intent_name = ? 
        AND (target_role = 'All' OR target_role = ?)
        AND is_active = 1
      LIMIT 1
    `;
    
    db.query(sql, [intentName, session.user_role], (err, results) => {
      if (err) {
        console.warn(`⚠️ DB error for ${intentName}:`, err.message);
        resolve(null);
        return;
      }
      
      if (results.length === 0) {
        console.warn(`⚠️ No response found for ${intentName}`);
        resolve(null);
        return;
      }
      
      resolve(results[0].response);
    });
  });
}




// ========== VICE CHANCELLOR INFO ==========
async function handleViceChancellorInfo(session) {
  const dbResponse = await getResponseFromDatabase('vice_chancellor_info', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `👔 **Vice Chancellor's Office**\n\n` +
    `The Vice Chancellor is the chief executive responsible for:\n` +
    `• Academic leadership and vision\n` +
    `• Administrative oversight\n` +
    `• Strategic planning and development\n` +
    `• Research and innovation initiatives\n\n` +
    `📞 **Contact:** +92-51-9290160\n` +
    `🌐 **Visit:** https://www.uaar.edu.pk/admin-vc.php`;
}

// ========== AVAILABLE FACULTIES ==========
async function handleAvailableFaculties(session) {
  const dbResponse = await getResponseFromDatabase('available_faculties', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `🎓 **Faculties at PMAS-AAUR**\n\n` +
    `**1. Faculty of Agriculture** - Agronomy, Horticulture, Soil Science\n\n` +
    `**2. Faculty of Veterinary & Animal Sciences** - Veterinary Sciences, Animal Sciences\n\n` +
    `**3. Faculty of Sciences** - Botany, Zoology, Chemistry, Physics, Mathematics\n\n` +
    `**4. Faculty of Social Sciences** - Economics, Sociology, Anthropology, Humanities\n\n` +
    `**5. Faculty of Agricultural Engineering & Technology**\n\n` +
    `🌐 **Details:** https://www.uaar.edu.pk`;
}

// ========== IT PROGRAMS INFO ==========
async function handleITProgramsInfo(session) {
  const dbResponse = await getResponseFromDatabase('it_programs', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `💻 **UIIT - University Institute of Information Technology**\n\n` +
    `**Undergraduate (BS):**\n` +
    `• BS Computer Science (4 years)\n` +
    `• BS Software Engineering (4 years)\n` +
    `• BS Information Technology (4 years)\n\n` +
    `**Graduate Programs:** MS Computer Science, MS Software Engineering, PhD Computer Science\n\n` +
    `📞 **Contact:** https://www.uaar.edu.pk/uiit/`;
}

// ========== BUSINESS PROGRAMS INFO ==========
async function handleBusinessProgramsInfo(session) {
  const dbResponse = await getResponseFromDatabase('business_programs', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `📊 **UIMS - University Institute of Management Sciences**\n\n` +
    `**Undergraduate:** BBA, BS Commerce\n\n` +
    `**Graduate:** MBA, MS Management Sciences, PhD Management Sciences\n\n` +
    `**Specializations:** Finance, Marketing, HR, Supply Chain Management\n\n` +
    `🌐 **More Info:** https://www.uaar.edu.pk/uims/`;
}

// ========== ADMISSION CRITERIA ==========
async function handleAdmissionCriteria(session) {
  const dbResponse = await getResponseFromDatabase('admission_criteria', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `📋 **Admission Criteria - PMAS-AAUR**\n\n` +
    `**Undergraduate (BS):**\n` +
    `• FSc (Pre-Medical/Pre-Engineering) or equivalent\n` +
    `• Minimum 50% aggregate\n` +
    `• Entry Test required\n\n` +
    `**Graduate (MS/M.Phil/PhD):**\n` +
    `• Relevant Bachelor's/Master's degree\n` +
    `• Minimum CGPA requirements\n` +
    `• GAT/NTS test (some programs)\n\n` +
    `📞 **Visit:** https://www.uaar.edu.pk/admissions.php`;
}

// ========== ADMISSION PROCESS ==========
async function handleAdmissionProcess(session) {
  const dbResponse = await getResponseFromDatabase('admission_process', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `📝 **How to Apply for Admission**\n\n` +
    `1️⃣ Check Eligibility\n` +
    `2️⃣ Get Admission Form\n` +
    `3️⃣ Fill Application\n` +
    `4️⃣ Submit Documents\n` +
    `5️⃣ Pay Admission Fee\n` +
    `6️⃣ Take Entry Test\n` +
    `7️⃣ Wait for Merit List\n` +
    `8️⃣ Complete Enrollment\n\n` +
    `🌐 **Apply Online:** https://www.uaar.edu.pk/admissions.php`;
}

// ========== ADMISSION DATES ==========
async function handleAdmissionDates(session) {
  const dbResponse = await getResponseFromDatabase('admission_dates', session);
  if (dbResponse) return dbResponse;
  
  // Fallback
  return `📅 **Admission Schedule**\n\n` +
    `**Fall Semester:** July-August (advertisement), Late August (deadline), Early September (test), Mid-September (classes start)\n\n` +
    `**Spring Semester:** December-January (advertisement), Late January (deadline), Early February (test), Late February (classes start)\n\n` +
    `💡 Don't miss deadlines - Apply early!\n\n` +
    `🌐 **Current Info:** https://www.uaar.edu.pk/admissions.php`;
}



// ========== TEACHER CONTACT & OFFICE INFO ==========

async function handleTeacherContact(session, entities, message) {
  return `📞 **Contacting Your Teachers:**

**Email Communication:**
📧 Most teachers have university email addresses
   Format: name@uaar.edu.pk
   
**Finding Teacher Email:**
💡 Ask me specifically: "What is [Teacher Name]'s email?"
   I'll search for their contact information

**Through Department:**
🏢 Contact your department office
📱 They can help connect you with teachers
⏰ Available during office hours

**Office Hours:**
🕐 Most teachers have designated office hours
📋 Check department notice board
📍 Usually posted outside teacher's office

**Best Practices:**
✅ Use your AAUR email for formal communication
✅ Write clear subject lines
✅ Be respectful and professional
✅ Give 24-48 hours for response
✅ For urgent matters, visit during office hours

**Emergency Contact:**
⚠️ For urgent academic matters
🏢 Contact department office
📞 They can help reach the teacher

💡 Professional communication is key!`;
}

async function handleTeacherOfficeLocation(session) {
  return `📍 **Finding Teacher Office Locations:**

**Department Buildings:**

🏢 **UIIT (Computer Sciences):**
   • IT Block
   • 3rd & 4th Floors mainly
   • Faculty rooms clearly marked

🌾 **Agriculture Departments:**
   • Main Academic Block
   • Faculty of Agriculture building
   • Separate wings for each department

🔬 **Sciences:**
   • Science Block
   • Department-wise distribution
   • Check department notice boards

💼 **UIMS (Management):**
   • Management Sciences Building
   • Ground and first floors

🐄 **Veterinary Sciences:**
   • Veterinary block
   • Near animal hospital

**How to Find:**
1️⃣ Visit your department office
2️⃣ Ask department staff
3️⃣ Check department notice board
4️⃣ Senior students can guide

**Office Hours Info:**
📋 Usually posted on office doors
🕐 Standard timings: 9 AM - 4 PM
⏰ Specific hours vary by teacher

**Important:**
🆔 Bring student ID when visiting
🤝 Knock before entering
⏰ Respect office hour timings
📝 May need appointment for detailed discussion

💡 **Pro Tip:** If teacher not available, leave a note with your contact info at department office`;
}


// ========== COMPLAINT FILING PROCESS ==========

async function handleComplaintFiling(session) {
  const isStudent = session.user_role === 'Student';
  
  return `📋 **How to File a Complaint:**

**Method 1: Through This App** ⭐
1️⃣ Go to 'Complaints' section in app
2️⃣ Tap 'File New Complaint' button
3️⃣ Fill in details:
   📝 Title (brief description)
   📋 Category (select from dropdown)
   📍 Location (select area)
   ✍️ Description (explain the issue)
   📸 Photo (optional but helpful)
4️⃣ Submit
5️⃣ Track status in 'My Complaints'

**Complaint Categories:**
🏗️ Infrastructure issues
🔧 Facility problems
📚 Academic concerns
📋 Administrative matters
🏠 Hostel issues
🚌 Transport problems
🌐 IT/Internet issues

**Method 2: University Website**
🌐 Visit: https://www.uaar.edu.pk/complaint.php
📝 Fill online complaint form
📧 Receives email confirmation

**Method 3: Direct Contact**
🏢 Visit relevant department office
📞 Call concerned department
📧 Email department head

**What Happens Next:**
✅ Complaint registered in system
👁️ Reviewed by admin
🔄 Status: Pending → In Progress → Resolved
📧 Updates sent via app notifications
⏰ Resolution time: Varies by issue

**Track Your Complaint:**
📱 Check 'My Complaints' in app
📊 View status updates
📅 See resolution timeline

**For Urgent Issues:**
🚨 Contact security (safety issues)
🏥 Medical emergency → Health center
⚡ Electricity/water → Estate office

**Tips for Effective Complaints:**
✅ Be specific and clear
✅ Provide exact location
✅ Add photos if possible
✅ Mention urgency level
✅ Follow up if no response in 48 hours

${isStudent ? '💡 **Student Tip:** Your feedback helps improve campus for everyone!' : '💡 Quick resolution depends on clear, detailed complaints'}

📞 **For Help:**
Contact admin office for assistance`;
}


// ========== RESULT CHECKING ==========

async function handleResultChecking(session) {
  const isStudent = session.user_role === 'Student';
  
  if (!isStudent) {
    return `📊 **Result Information for Faculty:**

As a faculty member, you can:

📝 **Submit Marks:**
• Through examination department portal
• Within specified deadline
• Follow marking scheme

📋 **Check Status:**
• Contact Controller of Examinations
• 🌐 https://www.uaar.edu.pk/exam/

📞 **Exam Office:**
• For result queries
• Mark submission issues
• Grade clarifications`;
  }
  
  return `📊 **How to Check Your Results:**

**Method 1: Student Portal** (Primary)
💻 Login to student portal
📱 Navigate to 'Results' or 'Academics' section
📊 View semester-wise results
📈 Check CGPA

**Portal Access:**
🌐 Check with IT department for exact URL
🔐 Login with student credentials
📧 May receive email when results uploaded

**Method 2: Department Notice Board**
📋 Results posted physically
🏢 Visit your department
📍 Check main notice board
📸 Take photo for record

**Method 3: University Website**
🌐 Visit: https://www.uaar.edu.pk
📢 Check announcements section
📰 Result notifications posted

**Method 4: Controller of Examinations**
🏢 Visit examination office
🆔 Bring student ID card
📄 Request printed result
💰 May have nominal charges

**Result Timeline:**
⏰ Usually 2-3 weeks after exams
📅 Mid-term: 1-2 weeks
📅 Final exams: 3-4 weeks
🎓 Final year: May take longer

**Result Components:**
📊 Individual course marks
📈 Semester GPA
📊 Cumulative GPA (CGPA)
✅ Pass/Fail status
🏆 Position (if applicable)

**If Results Delayed:**
📞 Contact your department
🏢 Check with examination office
📢 Watch for announcements

**Result Discrepancy:**
📝 Can apply for rechecking
📋 Get form from exam office
💰 Pay rechecking fee
⏰ Apply within specified time
🔍 Re-totaling or re-marking

**Transcript Request:**
📄 For official transcript
🏢 Visit Controller of Examinations
📝 Fill request form
💰 Pay fee (around PKR 500-1000)
⏰ Ready in 3-7 days

**Important:**
⚠️ Check spam folder for result emails
⚠️ Save soft copies of results
⚠️ Verify CGPA calculation
⚠️ Keep printed copies safe

📞 **Contact:**
🏢 Controller of Examinations
🌐 https://www.uaar.edu.pk/exam/
📧 Through your AAUR email

💡 **Pro Tip:** 
• Set portal notifications for result updates
• Join class group for result announcements
• Keep checking student portal regularly`;
}


// ========== ADMINISTRATION CONTACT ==========

async function handleAdministrationContact(session) {
  return `📞 **University Administration Contacts:**

**Main Office:**
📱 Phone: +92-51-9290160-7
📠 Fax: +92-51-9290160
📧 Email: info@uaar.edu.pk
📍 Main Administration Building

**Key Administrative Offices:**

👔 **Vice Chancellor's Office:**
📧 vc@uaar.edu.pk
🌐 https://www.uaar.edu.pk/admin-vc.php
📞 Extension: Check with operator

📋 **Registrar Office:**
📧 registrar@uaar.edu.pk
📞 +92-51-9290466
🌐 https://www.uaar.edu.pk/admin-registrar.php
📝 Handles: Academic records, admissions, regulations

💰 **Treasurer Office:**
📧 treasurer@uaar.edu.pk
🌐 https://www.uaar.edu.pk/admin-treasurer.php
💵 Handles: Fee payments, financial matters

📝 **Controller of Examinations:**
🌐 https://www.uaar.edu.pk/exam/
📊 Handles: Exams, results, transcripts, degrees

👨‍🎓 **Directorate of Student Affairs:**
🌐 https://www.uaar.edu.pk/dsa-home.php
🎓 Handles: Student issues, hostel, activities

🔬 **Directorate of Advanced Studies (DAS):**
🌐 https://www.uaar.edu.pk/das-home.php
🎓 Handles: MS/PhD programs

💡 **IT Services:**
🌐 https://www.uaar.edu.pk/services.php
💻 Handles: WiFi, email, portal issues

🏢 **Procurement Office:**
🌐 https://www.uaar.edu.pk/admin-procurement.php

🔐 **Estate Care & Security:**
🌐 https://www.uaar.edu.pk/estatecare.php
🚨 Emergency: Campus security

**General Inquiry:**
📞 Main switchboard: +92-51-9290160
🕐 Office hours: 9 AM - 4 PM (Mon-Fri)
📅 Friday: 9 AM - 12:30 PM

**Physical Address:**
📍 PMAS-Arid Agriculture University
📍 Shamsabad, Murree Road
📍 Rawalpindi, Punjab, Pakistan

**Online Resources:**
🌐 Main Website: https://www.uaar.edu.pk
📧 Complaint Cell: https://www.uaar.edu.pk/complaint.php
📱 Contact Form: https://www.uaar.edu.pk/contact-us.php

**Emergency Contacts:**
🚨 Campus Security: Available 24/7
🏥 Health Center: Campus medical facility
🔥 In case of fire/emergency: Contact security immediately

**Best Way to Reach:**
1️⃣ Email (for documentation)
2️⃣ Visit during office hours
3️⃣ Call for urgent matters
4️⃣ Online complaint for issues

💡 **Pro Tip:** 
• Always use your AAUR email for official communication
• Keep reference numbers for all communications
• Visit during early office hours for less wait time`;
}


// ========== FEE CONCESSION DETAILS ==========

async function handleFeeConcession(session) {
  const isStudent = session.user_role === 'Student';
  
  return `💰 **Fee Concession & Financial Relief:**

**Types of Concessions:**

1️⃣ **Merit-Based Concessions:**
   🏆 **Position Holders:**
   • 1st Position: 100% fee waiver
   • 2nd Position: 75% fee waiver
   • 3rd Position: 50% fee waiver
   
   📊 **High CGPA:**
   • CGPA > 3.5: 25-50% concession
   • CGPA > 3.0: 10-25% concession
   • Must maintain CGPA each semester
   
   🎯 **Entry Test Toppers:**
   • Top 10 scorers: Various concessions
   • 25-50% fee waiver

2️⃣ **Need-Based Financial Aid:**
   💰 For financially deserving students
   📋 Based on family income
   📄 Documentation required:
      • Income certificate (genuine)
      • Property documents
      • Utility bills
      • Affidavit
   🎯 Up to 50-100% support possible

3️⃣ **Special Category Concessions:**
   ⭐ **Hafiz-e-Quran:** Fee concession
   👥 **Orphans:** Special support
   ♿ **Disabled Students:** Full/partial waiver
   🕌 **Minorities:** Reserved quota
   👨‍👩‍👧 **University Employee Children:** Concession available
   🏅 **Sports Quota:** For national level players

4️⃣ **HEC/Government Scholarships:**
   🎓 Ehsaas Scholarship Program
   💳 PM Fee Reimbursement Scheme
   📚 PEEF (Punjab Educational Endowment Fund)
   🌟 Provincial scholarships

**Eligibility Criteria:**
✅ Pakistani citizen
✅ Regular student (75%+ attendance)
✅ Good academic standing
✅ Good conduct record
✅ Not receiving other major scholarship
✅ Meet specific category requirements

**Application Process:**

**For Merit-Based:**
1️⃣ Usually automatic for position holders
2️⃣ For CGPA-based: Apply to department
3️⃣ Submit academic transcripts
4️⃣ Fill application form

**For Need-Based:**
1️⃣ Get application from Financial Aid Office
2️⃣ Fill completely and honestly
3️⃣ Attach all required documents:
   📄 Income certificate (from relevant authority)
   📋 Asset declaration
   🏠 Property documents (if any)
   ⚡ Utility bills (last 3 months)
   🆔 CNIC copies (student + parents)
   📊 Academic record
   🏛️ Domicile certificate
4️⃣ Submit before deadline
5️⃣ Interview (if required)
6️⃣ Wait for committee decision

**Continuation Requirements:**
📈 Maintain required CGPA
📚 No fail subjects
✅ 75% minimum attendance
👤 Good conduct
📋 Timely re-application (if needed)

**Application Deadlines:**
📅 Usually at start of each semester
⏰ Don't miss deadlines
📢 Watch for announcements

**Committee Review:**
👥 Financial Assistance Committee
🔍 Reviews all applications
📊 Verifies documents
✅ Makes final decision
📧 Notifies students

**Payment After Concession:**
💵 Pay only remaining amount
🏦 Get updated fee challan
📄 Keep concession letter safe

**Important Notes:**
⚠️ Concessions reviewed each semester
⚠️ Can be revoked if requirements not met
⚠️ False information = Severe penalty
⚠️ Limited number of concessions available
⚠️ First come, first served (for some categories)

📞 **Apply Through:**
🏢 Directorate of Financial Assistance & University Advancement
🌐 http://sr.uaar.edu.pk/src/
📧 Contact through official email
📱 Visit office during working hours

**Additional Support:**
💼 Work-study programs
📚 Book bank facility
🖥️ Laptop scheme (if available)
💳 Emergency financial assistance
🏥 Medical support fund

**For Queries:**
🏢 Visit Financial Assistance Office
📞 Contact Student Affairs
📧 Email from AAUR account

${isStudent ? '💡 **Student Tip:** Don\'t hesitate to apply if you need financial support. The university wants to help deserving students complete their education!' : ''}

🎯 Education should not stop due to financial constraints - explore all options!`;
}

// ========== FEE & FINANCIAL HANDLERS ==========

async function handleUndergraduateFee(session) {
  const response = `💰 **BS Program Fee Structure**\n\n` +
    `📚 **Semester Fee (Approximate):**\n` +
    `• Tuition Fee: PKR 20,000 - 35,000\n` +
    `• Additional Charges: PKR 5,000 - 10,000\n` +
    `• **Total Per Semester:** PKR 25,000 - 45,000\n\n` +
    `**Varies by Program:**\n` +
    `• Agriculture Programs: Lower range\n` +
    `• Computer Science/IT: Higher range\n` +
    `• Engineering: Higher range\n\n` +
    `**One-Time Charges:**\n` +
    `• Admission Fee: PKR 10,000 - 15,000 (first semester)\n` +
    `• Security Deposit: PKR 5,000 (refundable)\n\n` +
    `**Additional Costs:**\n` +
    `• Library Fee: Included\n` +
    `• Sports Fee: Included\n` +
    `• Medical Fee: Included\n` +
    `• Hostel: PKR 15,000 - 25,000/semester (optional)\n` +
    `• Transport: PKR 5,000 - 12,000/semester (optional)\n\n` +
    `📊 **4-Year BS Total Cost:**\n` +
    `Approximately PKR 200,000 - 360,000 (tuition only)\n\n` +
    `💡 **Note:** Fees are subject to change. Contact Accounts Office for exact current fees.\n\n` +
    `📞 **For Details:** Contact Treasurer Office`;
  
  return response;
}

async function handleGraduateFee(session) {
  const response = `💰 **Graduate Programs Fee Structure**\n\n` +
    `📚 **MS/M.Phil Programs:**\n` +
    `• Semester Fee: PKR 30,000 - 55,000\n` +
    `• Thesis Fee: PKR 15,000 - 25,000\n` +
    `• **Total Program Cost:** PKR 150,000 - 300,000\n\n` +
    `🎓 **PhD Programs:**\n` +
    `• Semester Fee: PKR 35,000 - 65,000\n` +
    `• Research/Thesis Fee: PKR 30,000 - 50,000\n` +
    `• **Total Program Cost:** PKR 250,000 - 450,000\n\n` +
    `**Fee Components:**\n` +
    `• Tuition charges\n` +
    `• Library and research facilities\n` +
    `• Laboratory fees (if applicable)\n` +
    `• Examination fees\n\n` +
    `**Additional Charges:**\n` +
    `• Admission Fee: One-time\n` +
    `• Security Deposit: Refundable\n\n` +
    `💡 **Important Notes:**\n` +
    `• Fees vary by department and specialization\n` +
    `• Some programs receive HEC funding\n` +
    `• Scholarships may cover partial/full fees\n` +
    `• Contact DAS (Directorate of Advanced Studies) for exact fees\n\n` +
    `🌐 **DAS Portal:** http://cms.aaur.edu/DASsystem/public/\n\n` +
    `📞 **Contact:** Directorate of Advanced Studies`;
  
  return response;
}

async function handlePaymentMethod(session) {
  const response = `💳 **Fee Payment Methods**\n\n` +
    `**How to Pay:**\n\n` +
    `1️⃣ **Get Fee Challan:**\n` +
    `   • Visit Accounts Office\n` +
    `   • Provide student ID or registration number\n` +
    `   • Collect fee challan form\n\n` +
    `2️⃣ **Pay at Bank:**\n` +
    `   • Visit designated bank branches\n` +
    `   • **Bank:** (Usually HBL or NBP)\n` +
    `   • Pay exact amount mentioned\n` +
    `   • Get paid challan copy\n\n` +
    `3️⃣ **Submit to University:**\n` +
    `   • Return to Accounts Office\n` +
    `   • Submit paid challan copy\n` +
    `   • Get fee receipt\n\n` +
    `**Bank Account Details:**\n` +
    `• Contact Treasurer Office for:\n` +
    `  - Account number\n` +
    `  - Bank branches\n` +
    `  - Online payment options (if available)\n\n` +
    `⏰ **Important Deadlines:**\n` +
    `• Pay before semester fee deadline\n` +
    `• Late payment may incur fine\n` +
    `• Keep payment proof safe\n\n` +
    `📞 **For Help:**\n` +
    `• Treasurer Office: +92-51-9290160\n` +
    `• Visit: https://www.uaar.edu.pk/admin-treasurer.php\n\n` +
    `💡 Always pay fees on time to avoid late fee charges!`;
  
  return response;
}



// ========== SCHOLARSHIP HANDLERS ==========

async function handleHECScholarship(session) {
  const response = `🎓 **HEC Need-Based Scholarship**\n\n` +
    `**HEC provides scholarships for financially deserving students:**\n\n` +
    `💰 **Coverage:**\n` +
    `• Full tuition fee waiver\n` +
    `• Monthly stipend (PKR 5,000 - 7,000)\n` +
    `• Books and stationery support\n\n` +
    `✅ **Eligibility Criteria:**\n` +
    `• Pakistani citizen\n` +
    `• Enrolled in undergraduate program\n` +
    `• Minimum 60% marks in previous degree\n` +
    `• Family income below threshold\n` +
    `• Not holding any other scholarship\n\n` +
    `**Required Documents:**\n` +
    `• Admission proof/Student ID\n` +
    `• Academic transcripts\n` +
    `• Income certificate\n` +
    `• Domicile certificate\n` +
    `• CNIC copies\n` +
    `• Bank account details\n\n` +
    `📝 **How to Apply:**\n` +
    `1. Wait for HEC announcement\n` +
    `2. Apply through EHSAAS portal\n` +
    `3. Submit documents to university\n` +
    `4. Attend interview if required\n\n` +
    `📞 **Contact:**\n` +
    `• Financial Assistance Office\n` +
    `• Visit: http://sr.uaar.edu.pk/src/scholarships.php\n\n` +
    `🌐 **HEC Info:** https://hec.gov.pk/\n\n` +
    `💡 Apply as soon as announcements are made!`;
  
  return response;
}

async function handleMeritScholarship(session) {
  const response = `🏆 **Merit-Based Scholarships**\n\n` +
    `**For High Achievers:**\n\n` +
    `📊 **Categories:**\n\n` +
    `**1. Position Holders:**\n` +
    `   • 1st Position: 100% fee waiver\n` +
    `   • 2nd Position: 75% fee waiver\n` +
    `   • 3rd Position: 50% fee waiver\n\n` +
    `**2. High CGPA:**\n` +
    `   • CGPA > 3.5: 50% concession\n` +
    `   • CGPA > 3.0: 25% concession\n\n` +
    `**3. Entry Test Toppers:**\n` +
    `   • Top 10: Various concessions\n\n` +
    `✅ **Requirements:**\n` +
    `• Maintain required CGPA\n` +
    `• No fail subjects\n` +
    `• Good conduct certificate\n` +
    `• Regular attendance\n\n` +
    `**Continuation:**\n` +
    `• Scholarships reviewed each semester\n` +
    `• Must maintain academic performance\n` +
    `• Automatically renewed if criteria met\n\n` +
    `📝 **Application:**\n` +
    `• Usually automatic for position holders\n` +
    `• May need to apply for CGPA-based\n` +
    `• Submit application to concerned department\n\n` +
    `📞 **Contact:**\n` +
    `• Your Department Chairman\n` +
    `• Financial Assistance Office\n` +
    `• Visit: http://sr.uaar.edu.pk/src/\n\n` +
    `💡 Maintain excellent academic performance to secure scholarships!`;
  
  return response;
}
//---------------------------------start--------------------
//-----------------------------------------------------------
//-----------------------------------------------------------


async function handleAttendancePolicy(session) {
  const dbResponse = await getResponseFromDatabase('attendance_policy', session);
  if (dbResponse) {
    console.log('✅ Got attendance policy from DB');
    return dbResponse.response;
  }
  
  // Fallback
  console.log('⚠️ Using fallback attendance policy');
  return `📊 **PMAS-Arid Agriculture University - Attendance Policy:**

**Minimum Requirement:**
✅ 75% attendance is MANDATORY
❌ Below 75% = Barred from exams

**How to Check:**
📱 Student Portal
👨‍🏫 Course teacher
📊 Department office

**Valid Reasons:**
🏥 Medical emergency
👨‍👩‍👧 Family emergency
🏛️ University activities

💡 Keep attendance above 80% for safety!`;
}

async function getResponseFromDatabase(intentName, session, entities) {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT * FROM chatbot_responses 
      WHERE intent_name = ? 
        AND (target_role = 'All' OR target_role = ?)
        AND is_active = 1
      LIMIT 1
    `;
    
    db.query(sql, [intentName, session.user_role], (err, results) => {
      if (err) {
        // ✅ Log error and continue gracefully
        console.warn(`⚠️  DB error for intent "${intentName}":`, err.message);
        resolve(null);  // Return null, don't reject
        return;
      }
      
      if (results.length === 0) {
        resolve(null);
        return;
      }
      
      const record = results[0];
      
      // If static response, return as-is
      if (record.response_type === 'static' || record.response_type === 'hybrid') {
        let response = record.response;
        
        // Replace placeholders
        if (response.includes('{user_name}')) {
          response = response.replace('{user_name}', session.user_name);
        }
        if (response.includes('{user_role}')) {
          response = response.replace('{user_role}', session.user_role);
        }
        
        console.log(`✅ DB Response loaded for: ${intentName}`);
        
        resolve({
          response: response,
          responseType: record.response_type,
          questionAsked: record.question,
          category: record.category
        });
      } else {
        // For dynamic responses, return null so code continues to handlers
        console.log(`ℹ️  Dynamic intent: ${intentName} - Using handler function`);
        resolve(null);
      }
    });
  });
}


// ========== GRADING SYSTEM HANDLER ==========
async function handleGradingSystem(session) {
  const dbResponse = await getResponseFromDatabase('grading_system', session);
  if (dbResponse) return dbResponse.response;
  
  // Fallback
  return `📊 **PMAS-Arid Grading System:**

**Grade Scale:**
🅰️ A: 85-100 → 4.00
🅱️ B+: 80-84 → 3.50
🅱️ B: 75-79 → 3.00
🆎 B-: 71-74 → 2.50
🅲️ C+: 68-70 → 2.25
🅲️ C: 64-67 → 2.00
🅲️ C-: 60-63 → 1.75
🅳️ D: 50-59 → 1.00
❌ F: Below 50 → 0.00

**GPA Formula:**
GPA = Σ(Grade Points × Credit Hours) ÷ Total Credit Hours

**Example:**
Math (3CH) B (3.0) = 9.0
English (3CH) A (4.0) = 12.0
Total: 21.0 ÷ 6 CH = 3.50 GPA ✅

**Check Your GPA:**
📱 Student Portal
📧 Controller of Examinations

💡 Minimum 2.00 CGPA required to graduate!`;
}

// ========== EXAM POLICIES HANDLER ==========
async function handleExamPolicies(session) {
  const dbResponse = await getResponseFromDatabase('exam_policies', session);
  if (dbResponse) return dbResponse.response;
  
  return `📋 **Exam Policies & Rules:**

**Requirements:**
✅ 75% attendance mandatory
🆔 ID card required
📱 No mobile phones allowed

**During Exam:**
🚫 No talking or cheating
✍️ Use blue/black pen only
⏰ Arrive 15 minutes early

**Penalties for Cheating:**
❌ Exam cancellation
❌ Course failure  
⚠️ Possible suspension

📞 Contact: Controller of Examinations`;
}

// ========== CREDIT HOURS SYSTEM HANDLER ==========
async function handleCreditHoursSystem(session) {
  const dbResponse = await getResponseFromDatabase('credit_hours_system', session);
  if (dbResponse) return dbResponse.response;
  
  return `📚 **Credit Hours System:**

**What is it?**
📖 1 Credit Hour = 1 hour lecture/week for 16 weeks
🔬 Lab = 3 hours/week for 1 credit hour

**Course Structure:**
📝 Theory: Usually 3 credit hours
🧪 Lab: Usually 1 credit hour
📊 Combined: 4 credit hours total

**Semester Load:**
✅ Minimum: 12 credit hours (full-time)
✅ Normal: 15-18 credit hours
✅ Maximum: 21 credit hours

**Degree Requirement:**
🎓 BS Programs: 130-136 credit hours (4 years)

💡 Higher credit courses have more impact on CGPA!`;
}

// ========== HOW TO APPLY ADMISSION HANDLER ==========
async function handleHowToApply(session) {
  const dbResponse = await getResponseFromDatabase('how_to_apply_admission', session);
  if (dbResponse) return dbResponse.response;
  
  return `📝 **How to Apply:**

**Quick Steps:**
1️⃣ Check eligibility
2️⃣ Get admission form (online/offline)
3️⃣ Fill form + attach documents
4️⃣ Submit application
5️⃣ Pay entry test fee
6️⃣ Appear for test
7️⃣ Check merit list
8️⃣ Deposit fee if selected
9️⃣ Complete enrollment

**Required Documents:**
✅ Certificates (attested)
✅ CNIC copies
✅ Domicile
✅ Photos
✅ Character certificate

📞 Admissions: +92-51-9290160
🌐 www.uaar.edu.pk/admissions`;
}

// ========== ADMISSION ELIGIBILITY HANDLER ==========
async function handleAdmissionEligibility(session) {
  const dbResponse = await getResponseFromDatabase('admission_eligibility', session);
  if (dbResponse) return dbResponse.response;
  
  return `📋 **Admission Eligibility:**

**Undergraduate:**
✅ FSc (Pre-Med/Pre-Eng) with 50% minimum
✅ A-Levels with 2 principal passes
✅ ICS/I.Com for relevant programs

**Graduate (MS/M.Phil):**
✅ Relevant Bachelor's (16 years)
✅ Minimum 2.50 CGPA or 50%
✅ GAT General (for some programs)

**PhD:**
✅ Relevant MS/M.Phil
✅ Minimum 3.00 CGPA
✅ GAT Subject (60%)

**Special Quotas:**
🏅 2% disabled persons
🏅 2% minorities
🏅 1% orphans

📞 Contact Admissions for specific program requirements`;
}

// ========== ADMISSION SCHEDULE HANDLER ==========
async function handleAdmissionSchedule(session) {
  const dbResponse = await getResponseFromDatabase('admission_schedule', session);
  if (dbResponse) return dbResponse.response;
  
  return `📅 **Admission Schedule:**

**Fall Semester (Main):**
📢 Advertisement: June-July
📝 Applications: July
✏️ Entry Test: Early August
📊 Merit List: Late August
🎓 Classes: September

**Spring Semester (Limited):**
📢 Advertisement: December  
📝 Applications: January
✏️ Entry Test: February
📊 Merit List: Mid February
🎓 Classes: March

⏰ Deadlines are strict - Apply early!

🌐 www.uaar.edu.pk/admissions
📞 +92-51-9290160`;
}

// ========== STEP BY STEP ADMISSION HANDLER ==========
async function handleStepByStepAdmission(session) {
  const dbResponse = await getResponseFromDatabase('step_by_step_admission', session);
  if (dbResponse) return dbResponse.response;
  
  return `📝 **Step-by-Step Admission:**

**1️⃣ Check Eligibility** → Review requirements
**2️⃣ Get Form** → Online/Offline purchase
**3️⃣ Collect Documents** → Certificates, CNIC, photos
**4️⃣ Fill Form** → Complete accurately
**5️⃣ Submit Application** → Before deadline
**6️⃣ Pay Test Fee** → Bank deposit
**7️⃣ Download Admit Card** → 3-5 days before test
**8️⃣ Prepare** → Study syllabus
**9️⃣ Take Test** → Bring ID + admit card
**🔟 Check Merit** → After 1-2 weeks
**1️⃣1️⃣ Pay Fee** → If selected (within 7 days)
**1️⃣2️⃣ Document Verification** → Original certificates
**1️⃣3️⃣ Get Student ID** → Photo + collection
**1️⃣4️⃣ Register Courses** → Meet advisor
**1️⃣5️⃣ Orientation** → Attend session
**1️⃣6️⃣ Start Classes!** → Begin journey

📞 Need help? Admissions Office
🌐 www.uaar.edu.pk`;
}

// ========== MY SCHEDULE TODAY - STUDENT HANDLER ==========
// ========== MY SCHEDULE TODAY (STUDENT + TEACHER) ==========
async function handleMyScheduleToday(session, entities) {
  return new Promise((resolve, reject) => {

    // Get today's weekday
    const todayDate = new Date();
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const today = days[todayDate.getDay()];

    console.log(`🗓 Fetching schedule for today: ${today}`);
    console.log(`👤 User: ${session.user_name}, Role: ${session.user_role}`);

    let sql = '';
    let params = [];

    // ================= STUDENT =================
    if (session.user_role === 'Student') {

      console.log(`🎓 Degree: ${session.user_degree}, Section: ${session.user_section}, Semester: ${session.user_semester}`);

      sql = `
        SELECT * FROM class_schedules
        WHERE degree = ?
          AND section = ?
          AND semester_no = ?
          AND day_of_week = ?
          AND is_active = 1
        ORDER BY start_time ASC
      `;

      params = [
        session.user_degree,
        session.user_section,
        session.user_semester,
        today
      ];

    }

    // ================= TEACHER =================
    else if (session.user_role === 'Teacher') {

      console.log(`👨‍🏫 Teacher: ${session.user_name}`);

      sql = `
        SELECT * FROM class_schedules
        WHERE teacher_name = ?
          AND day_of_week = ?
          AND is_active = 1
        ORDER BY start_time ASC
      `;

      params = [
        session.user_name,
        today
      ];
    }

    else {
      resolve("⚠️ Unable to determine your role. Please login again.");
      return;
    }

    // ================= EXECUTE QUERY =================
    db.query(sql, params, (err, results) => {
      if (err) {
        console.error('❌ Schedule fetch error:', err);
        reject(err);
        return;
      }

      console.log(`✅ Found ${results.length} classes`);

      if (results.length === 0) {
        resolve(`🎉 You have no classes today (${today})!`);
        return;
      }

      let response = `📅 **Your Schedule for Today (${today}):**\n\n`;

      results.forEach((cls, index) => {
        const startTime = cls.start_time?.substring(0, 5) || 'TBA';
        const endTime = cls.end_time?.substring(0, 5) || 'TBA';

        response += `${index + 1}. **${cls.subject_name}**\n`;
        response += `   ⏰ ${startTime} - ${endTime}\n`;

        if (session.user_role === 'Student') {
          response += `   👨‍🏫 ${cls.teacher_name || 'TBA'}\n`;
        }

        if (session.user_role === 'Teacher') {
          response += `   🎓 ${cls.degree} - Section ${cls.section} (Sem ${cls.semester_no})\n`;
        }

        response += `   📍 ${cls.room_number || 'TBA'}\n`;
        if (cls.building) response += `   🏢 ${cls.building}\n`;

        response += `\n`;
      });

      resolve(response.trim());
    });

  });
}

// ========== UNIVERSITY INFO HANDLER ==========
async function handleUniversityInfo(session) {
  // Try to get DB response
  const dbResponse = await getResponseFromDatabase('university_info', session);

  if (dbResponse) {
    return dbResponse.response;
  }

  // Fallback in case DB has no entry
  return `🎓 **PMAS-Arid Agriculture University (U A A N)**

📍 Located in Rawalpindi/Islamabad, Pakistan.  
🏛 Offers a wide range of undergraduate and postgraduate programs in agriculture, engineering, sciences, business, and social sciences.  
🎯 Known for research excellence, modern campus facilities, and academic culture.

Visit the official website: https://www.uaar.edu.pk for detailed info on admissions, departments, and programs.

If you want more details (fees, departments, admission dates), let me know! 😊`;
}

// ========== UNIVERSITY DEPARTMENTS HANDLER ==========
async function handleUniversityDepartments(session) {
  // Try to get response from DB
  const dbResponse = await getResponseFromDatabase('university_departments', session);

  if (dbResponse) {
    return dbResponse.response;
  }

  // Fallback if DB fails
  return `🏛 PMAS-Arid Agriculture University offers multiple faculties including:

🌾 Crop & Food Sciences (Agronomy, Horticulture, Plant Pathology, Genetics, Entomology, Extension, Forestry & Range)
🔬 Sciences (Botany, Zoology, Chemistry, Physics, Math, Statistics, Eastern Medicine)
🐄 Veterinary & Animal Sciences (Biomedical, Parasitology, Clinical, Pathology)
⚙️ Agricultural Engineering & Technology (Structures, Machinery, Land & Water, Energy, Precision Agriculture)
📊 Social Sciences (Economics, Sociology, Humanities, Education)
💻 Institutes & Specialized Units (UIIT, Management, Biochemistry, Soil & Environment, Food & Nutrition, Animal Sciences)

Visit https://www.uaar.edu.pk for detailed info.

You can ask me about a specific department for more details.`;
}

// ========== EXAM INFO HANDLER ==========
async function handleExamInfo(session) {
  const dbResponse = await getResponseFromDatabase('exam_info', session);

  if (dbResponse) {
    return dbResponse.response;
  }

  return `📝 PMAS-Arid Agriculture University conducts entry tests for eligible students.
Visit https://www.uaar.edu.pk/admissions for registration, schedule, and fee details.`;
}

// ========== ADMISSIONS INFO HANDLER ==========
async function handleAdmissionsInfo(session) {
  const dbResponse = await getResponseFromDatabase('admissions_info', session);

  if (dbResponse) {
    return dbResponse.response;
  }

  return `🎯 PMAS-Arid University announces merit lists after entry test results.
Check https://www.uaar.edu.pk/admissions for exact dates and merit positions.`;
}

// ================== 1️⃣ CS Programs Handler ==================
async function handleCSPrograms(session) {
  const dbResponse = await getResponseFromDatabase('cs_programs', session);
  if (dbResponse) return dbResponse.response;

  return `💻 Faculty of Engineering & IT (UIIT):
- BS Computer Science, Software Engineering, IT
- Duration: 4 years
- Focus: Programming, Networking, Software Development
- Admission: Entry test & merit list
More info: https://www.uaar.edu.pk`;
}

// ================== 2️⃣ Agriculture Programs Handler ==================
async function handleAgriculturePrograms(session) {
  const dbResponse = await getResponseFromDatabase('agriculture_programs', session);
  if (dbResponse) return dbResponse.response;

  return `🎓 Faculty of Agriculture:
- BS Agronomy, Horticulture, Plant Pathology, Entomology, Soil Science, Agricultural Economics
- Duration: 4 years
- Admission: Entry test & merit list
More info: https://www.uaar.edu.pk`;
}

// ================== 3️⃣ Business & Management Programs Handler ==================
async function handleBusinessPrograms(session) {
  const dbResponse = await getResponseFromDatabase('business_programs', session);
  if (dbResponse) return dbResponse.response;

  return `💼 Faculty of Social Sciences / UIMS:
- BBA, MBA, Economics, Education, Sociology
- Duration: 4 years (BBA), 2 years (MBA)
- Admission: Entry test & merit list
More info: https://www.uaar.edu.pk`;
}

// ================== 4️⃣ Veterinary Programs Handler ==================
async function handleVeterinaryPrograms(session) {
  const dbResponse = await getResponseFromDatabase('veterinary_programs', session);
  if (dbResponse) return dbResponse.response;

  return `🐄 Faculty of Veterinary & Animal Sciences:
- BS Animal Sciences, BS Veterinary Sciences
- Duration: 4 years
- Admission: Entry test & merit list
More info: https://www.uaar.edu.pk`;
}

// ================== Campus Facilities Overview ==================
async function handleCampusFacilities(session) {
  const dbResponse = await getResponseFromDatabase('campus_facilities', session);
  return dbResponse ? dbResponse.response : `🏫 Campus facilities include cafeteria, WiFi, gym, sports grounds, library, health center, and transport services.`;
}

// ================== Cafeteria ==================
async function handleCafeteriaInfo(session) {
  const dbResponse = await getResponseFromDatabase('cafeteria_info', session);
  return dbResponse ? dbResponse.response : `🍴 Cafeteria timings: Breakfast 8-10AM, Lunch 12:30-2:30PM, Snacks 10:30-5PM. Menu updated weekly.`;
}

// ================== WiFi ==================
async function handleWiFiInfo(session) {
  const dbResponse = await getResponseFromDatabase('wifi_info', session);
  return dbResponse ? dbResponse.response : `🌐 WiFi available campus-wide for students & staff. Login with university credentials.`;
}

// ================== Gym ==================
async function handleGymInfo(session) {
  const dbResponse = await getResponseFromDatabase('gym_info', session);
  return dbResponse ? dbResponse.response : `🏋️ Gym open 7AM-9PM, includes cardio, weights, aerobics. Trainers available during peak hours.`;
}

// ================== Sports ==================
async function handleSportsInfo(session) {
  const dbResponse = await getResponseFromDatabase('sports_info', session);
  return dbResponse ? dbResponse.response : `⚽ Sports facilities: Football, Basketball, Volleyball, Cricket. Indoor & outdoor grounds available.`;
}

// ================== Fee Structure Handler ==================
async function handleFeeStructure(session) {
  const dbResponse = await getResponseFromDatabase('fee_structure_info', session);
  return dbResponse ? dbResponse.response : `💰 Fee structure details are available for BS, MS, and PhD programs. Check https://www.uaar.edu.pk/admissions/fee-structure`;
}

// ================== Transport Info Handler ==================
async function handleTransportInfo(session) {
  const dbResponse = await getResponseFromDatabase('transport_info', session);
  return dbResponse ? dbResponse.response : `🚌 Campus transport available with charges from PKR 500-1,500 per semester. Check the transport office for routes and schedules.`;
}

// ================== Fee Concession Handler ==================
async function handleFeeConcession(session) {
  const dbResponse = await getResponseFromDatabase('fee_concession_info', session);
  return dbResponse ? dbResponse.response : `🎓 Merit-based and need-based fee concessions are available. Check https://www.uaar.edu.pk/scholarships for eligibility and application.`;
}

// ================== Medical Services Handler ==================
async function handleMedicalServices(session) {
  const dbResponse = await getResponseFromDatabase('medical_services', session);
  return dbResponse ? dbResponse.response : `🏥 Health Center available for students & staff. Emergency care provided on campus.`;
}

// ================== Emergency Contacts Handler ==================
async function handleEmergencyContacts(session) {
  const dbResponse = await getResponseFromDatabase('emergency_contacts', session);
  return dbResponse ? dbResponse.response : `📞 Campus emergency numbers: Security, Health Center, Ambulance, Fire Brigade. Keep handy!`;
}

// ================== Developers Info Handler ==================
async function handleDevelopersInfo(session) {
  const dbResponse = await getResponseFromDatabase('developers_info', session);
  return dbResponse ? dbResponse.response : `👨‍💻 This app was developed by the Final Year Project team of PMAS-Arid University.`;
}

// ================== Chatbot Usage Handler ==================
async function handleChatbotUsage(session) {
  const dbResponse = await getResponseFromDatabase('chatbot_usage', session);
  return dbResponse ? dbResponse.response : `🤖 Ask about programs, fees, campus facilities, exam info, or contacts. Multilingual support available.`;
}

async function handleUniversityLocation(session) {
  const dbResponse = await getResponseFromDatabase('university_location', session);
  return dbResponse ? dbResponse.response : 
    "📍 PMAS-Arid Agriculture University Rawalpindi, Shamsabad, Murree Road. Registrar: +92-51-9292122";
}

async function handleCareerServices(session) {
  const dbResponse = await getResponseFromDatabase('career_services', session);
  return dbResponse ? dbResponse.response : 
    "🎯 Career & Student Counseling is available through the Directorate of Student Affairs. Contact the office on campus.";
}

async function handleStudentServices(session) {
  const dbResponse = await getResponseFromDatabase('student_services', session);
  return dbResponse ? dbResponse.response : 
    "🧑‍🎓 Access the student portal via the official PMAS-Arid University portal using your student credentials.";
}

async function handleLibraryMembership(session) {
  const dbResponse = await getResponseFromDatabase('library_membership', session);
  return dbResponse ? dbResponse.response : 
    "📚 Library membership is automatic for all enrolled students. Visit the Central Library or contact staff for details.";
}

async function handleGreeting(session) {
  const dbResponse = await getResponseFromDatabase('greeting', session);
  return dbResponse ? dbResponse.response :
    "👋 Hello! How can I assist you today?";
}

async function handleHowAreYou(session) {
  const dbResponse = await getResponseFromDatabase('how_are_you', session);
  return dbResponse ? dbResponse.response :
    "😊 I am doing great! How can I help you?";
}

async function handleBotName(session) {
  const dbResponse = await getResponseFromDatabase('bot_name', session);
  return dbResponse ? dbResponse.response :
    "🤖 I am your Campus Assistant.";
}

async function handleFriendRequest(session) {
  const dbResponse = await getResponseFromDatabase('friend_request', session);
  return dbResponse ? dbResponse.response :
    "😊 I am always here for you!";
}

async function handleLoveExpression(session) {
  const dbResponse = await getResponseFromDatabase('love_expression', session);
  return dbResponse ? dbResponse.response :
    "❤️ Thank you!";
}

async function handleAbusiveLanguage(session) {
  const dbResponse = await getResponseFromDatabase('abusive_language', session);
  return dbResponse ? dbResponse.response :
    "⚠️ Please keep the conversation respectful.";
}

async function handleThanks(session) {
  const dbResponse = await getResponseFromDatabase('thanks', session);
  return dbResponse ? dbResponse.response :
    "🙏 You're welcome!";
}

async function handleDefault(session) {
  return "I did not understand that. Could you please rephrase?";
}

// ========================================
// SADNESS INTENT HANDLERS
// ========================================

/**
 * Handler for main 'feeling_sad' intent
 */
async function handleFeelingSad(session) {
  const dbResponse = await getResponseFromDatabase('feeling_sad', session);
  return dbResponse ? dbResponse.response :
    "💙 I am really sorry that you are feeling this way. It is completely okay to feel sad sometimes — emotions are a natural part of being human. If something specific is bothering you, you can share it with me. Even small steps like taking a short walk, listening to calming music, or speaking with someone you trust can help lighten the weight a little. Remember, tough moments do not last forever, and you are stronger than you think.";
}

/**
 * Handler for 'why_am_i_sad' intent
 */
async function handleWhyAmISad(session) {
  const dbResponse = await getResponseFromDatabase('why_am_i_sad', session);
  return dbResponse ? dbResponse.response :
    "💭 Sadness can come from many sources — disappointment, loss, stress, loneliness, or sometimes it appears without a clear reason. It is your mind processing emotions and experiences. If the sadness feels overwhelming or lasts for weeks, it might help to talk to someone you trust or consider speaking with a counselor. Understanding your emotions is the first step toward healing.";
}

/**
 * Handler for 'how_to_stop_sadness' intent
 */
async function handleHowToStopSadness(session) {
  const dbResponse = await getResponseFromDatabase('how_to_stop_sadness', session);
  return dbResponse ? dbResponse.response :
    "🌈 Here are some gentle steps that might help: 1) Talk to someone you trust about how you feel. 2) Do something small that brings you comfort — listen to music, take a walk, or spend time in nature. 3) Practice self-compassion and remind yourself that it is okay to feel this way. 4) Engage in light physical activity or a hobby you enjoy. 5) If the sadness persists for more than two weeks, consider reaching out to a mental health professional. Small actions can lead to gradual healing.";
}

/**
 * Handler for 'want_to_cry' intent
 */
async function handleWantToCry(session) {
  const dbResponse = await getResponseFromDatabase('want_to_cry', session);
  return dbResponse ? dbResponse.response :
    "💧 Crying is a healthy and natural way to release emotions. It is okay to cry — it does not make you weak. In fact, research shows that crying can help reduce stress and provide emotional relief. Let yourself feel what you need to feel. If you have been crying frequently and feel overwhelmed, it might help to talk to a friend, family member, or counselor who can support you through this.";
}

/**
 * Handler for 'am_i_depressed' intent
 */
async function handleAmIDepressed(session) {
  const dbResponse = await getResponseFromDatabase('am_i_depressed', session);
  return dbResponse ? dbResponse.response :
    "🩺 Sadness is a normal emotion that usually fades with time, while depression is a medical condition that lasts for at least two weeks and affects daily functioning. Signs of depression include: persistent sadness, loss of interest in activities you once enjoyed, changes in sleep or appetite, fatigue, difficulty concentrating, and feelings of worthlessness. If you have experienced several of these symptoms for more than two weeks, I strongly encourage you to speak with a mental health professional. You deserve proper support and care.";
}

/**
 * Handler for 'feeling_empty' intent - HIGH PRIORITY
 */
async function handleFeelingEmpty(session) {
  const dbResponse = await getResponseFromDatabase('feeling_empty', session);
  return dbResponse ? dbResponse.response :
    "🤍 Feeling empty or numb can be very distressing. This can happen when emotions become overwhelming, and your mind tries to protect you by shutting down feelings temporarily. It can also be a sign of depression or emotional exhaustion. Please consider talking to a mental health professional who can help you process these feelings safely. You do not have to go through this alone — support is available.";
}

/**
 * Handler for 'sad_no_reason' intent
 */
async function handleSadNoReason(session) {
  const dbResponse = await getResponseFromDatabase('sad_no_reason', session);
  return dbResponse ? dbResponse.response :
    "🌙 Sometimes sadness appears without an obvious trigger. This can be due to chemical imbalances in the brain, accumulated stress, fatigue, or subtle emotional processing happening beneath the surface. It is completely valid to feel sad even when everything seems fine on the outside. If this feeling persists or worsens, consider talking to a counselor or doctor. Your feelings are real and deserve attention.";
}

/**
 * Handler for 'feeling_worthless' intent - CRITICAL PRIORITY
 * This requires special attention as it may indicate crisis
 */
async function handleFeelingWorthless(session) {
  const dbResponse = await getResponseFromDatabase('feeling_worthless', session);
  
  // Log this interaction for safety monitoring
  await logHighPriorityInteraction(session, 'feeling_worthless');
  
  return dbResponse ? dbResponse.response :
    "❤️‍🩹 I am truly sorry you are feeling this way. These thoughts are symptoms of deep emotional pain, not the truth about who you are. You matter, and your life has value — even when it does not feel that way right now. Please reach out to someone who can support you: a trusted friend, family member, counselor, or crisis helpline. If you are in immediate danger or having thoughts of self-harm, please contact emergency services or a crisis hotline immediately. You deserve help and compassion.";
}

/**
 * Helper function to log high-priority emotional interactions
 * This can be used for safety monitoring and follow-up
 */
async function logHighPriorityInteraction(session, intentName) {
  try {
    // Log to database for monitoring
    await database.query(`
      INSERT INTO high_priority_interactions 
      (session_id, user_id, intent_name, timestamp) 
      VALUES (?, ?, ?, NOW())
    `, [session.id, session.user_id, intentName]);
    
    // Optionally, trigger alert for human review
    if (intentName === 'feeling_worthless') {
      // await notifyMentalHealthTeam(session);
    }
  } catch (error) {
    console.error('Error logging high-priority interaction:', error);
  }
}

// ========================================
// STRESS & ANXIETY INTENT HANDLERS
// ========================================

/**
 * Handler for main 'stressed' intent
 */
async function handleStressed(session) {
  const dbResponse = await getResponseFromDatabase('stressed', session);
  return dbResponse ? dbResponse.response :
    "🧘 It sounds like you are under a lot of pressure right now. Stress can feel overwhelming, especially during exams or deadlines. Try to pause for a moment — take a deep breath, organize your tasks into smaller steps, and focus on one thing at a time. You do not have to solve everything at once. Managing stress starts with slowing down and regaining control step by step. You are capable of handling this.";
}

/**
 * Handler for 'how_to_reduce_stress' intent
 */
async function handleHowToReduceStress(session) {
  const dbResponse = await getResponseFromDatabase('how_to_reduce_stress', session);
  return dbResponse ? dbResponse.response :
    "🌿 Here are effective ways to reduce stress: 1) **Deep breathing**: Try the 4-7-8 technique (breathe in for 4, hold for 7, exhale for 8). 2) **Break tasks down**: Focus on one small task at a time instead of the entire workload. 3) **Physical activity**: Even a 10-minute walk can release tension. 4) **Talk it out**: Share your worries with someone you trust. 5) **Time management**: Prioritize tasks and set realistic deadlines. 6) **Rest**: Give yourself permission to take breaks. Small steps make a big difference.";
}

/**
 * Handler for 'overwhelmed_tasks' intent
 */
async function handleOverwhelmedTasks(session) {
  const dbResponse = await getResponseFromDatabase('overwhelmed_tasks', session);
  return dbResponse ? dbResponse.response :
    "📋 Feeling overwhelmed by tasks is very common. Here is what can help: 1) **Write everything down**: Get it out of your head and onto paper or a digital list. 2) **Prioritize**: Identify the 2-3 most urgent/important tasks. 3) **Start small**: Complete one easy task to build momentum. 4) **Delegate or ask for help** if possible. 5) **Set boundaries**: It is okay to say no to new commitments. 6) **Break it down**: Divide large tasks into tiny, manageable steps. You do not have to do everything perfectly or all at once.";
}

/**
 * Handler for 'stress_physical_symptoms' intent
 */
async function handleStressPhysicalSymptoms(session) {
  const dbResponse = await getResponseFromDatabase('stress_physical_symptoms', session);
  return dbResponse ? dbResponse.response :
    "💆 Stress can definitely cause physical symptoms like headaches, stomach issues, muscle tension, and chest tightness. Your body is telling you that stress levels are high. Here is what might help: 1) Practice relaxation techniques (deep breathing, progressive muscle relaxation). 2) Stay hydrated and eat regular meals. 3) Get adequate sleep. 4) Gentle stretching or light exercise can release physical tension. If symptoms persist or worsen, please see a doctor to rule out other medical causes. Your physical health matters.";
}

/**
 * Handler for main 'nervous' intent
 */
async function handleNervous(session) {
  const dbResponse = await getResponseFromDatabase('nervous', session);
  return dbResponse ? dbResponse.response :
    "💭 Feeling nervous usually means you care about the outcome — and that is a good thing. Try to prepare calmly and remind yourself of the effort you have already made. Take slow breaths and focus on what you can control. Nervousness is temporary, but your preparation and dedication will stay with you. You have got this!";
}

/**
 * Handler for 'how_to_calm_anxiety' intent
 */
async function handleHowToCalmAnxiety(session) {
  const dbResponse = await getResponseFromDatabase('how_to_calm_anxiety', session);
  return dbResponse ? dbResponse.response :
    "🌊 Here are immediate anxiety relief techniques: 1) **Grounding (5-4-3-2-1)**: Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, 1 you taste. 2) **Box breathing**: Breathe in for 4, hold for 4, out for 4, hold for 4. Repeat. 3) **Move your body**: Walk, stretch, or do jumping jacks to release nervous energy. 4) **Challenge anxious thoughts**: Ask yourself, 'Is this thought based on facts or feelings?' 5) **Stay present**: Focus on this moment, not 'what ifs.' You can get through this moment.";
}

/**
 * Handler for 'panic_attack' intent - CRITICAL PRIORITY
 */
async function handlePanicAttack(session) {
  const dbResponse = await getResponseFromDatabase('panic_attack', session);
  
  // Log this as high priority
  await logHighPriorityInteraction(session, 'panic_attack');
  
  return dbResponse ? dbResponse.response :
    "🆘 If you are having a panic attack, please know: **You are safe. This will pass. You are not in danger.** Try these steps right now: 1) **Breathe slowly**: Inhale through your nose for 4 counts, exhale through your mouth for 6 counts. 2) **Ground yourself**: Touch something cold, splash water on your face, or hold ice. 3) **Remind yourself**: 'This is temporary. I have survived this before.' If symptoms continue or you feel you cannot breathe properly, please seek immediate medical attention or call emergency services. If panic attacks are frequent, please speak with a mental health professional.";
}

/**
 * Handler for 'worried_about_future' intent
 */
async function handleWorriedAboutFuture(session) {
  const dbResponse = await getResponseFromDatabase('worried_about_future', session);
  return dbResponse ? dbResponse.response :
    "🔄 Overthinking and worrying about the future is exhausting. Here is what might help: 1) **Stay present**: You can only control what is happening now. Ask yourself, 'What can I do in this moment?' 2) **Write it down**: Getting worries out of your head and onto paper can reduce their power. 3) **Set a 'worry time'**: Give yourself 15 minutes to worry, then move on. 4) **Challenge 'what if' thoughts**: Replace them with 'even if' — 'Even if X happens, I can handle it.' You are stronger than your worries.";
}

/**
 * Handler for 'exam_anxiety' intent
 */
async function handleExamAnxiety(session) {
  const dbResponse = await getResponseFromDatabase('exam_anxiety', session);
  return dbResponse ? dbResponse.response :
    "📚 Exam anxiety is very common. Here is how to manage it: 1) **Prepare well in advance**: Break study material into small chunks and review daily. 2) **Practice relaxation**: Before the exam, take deep breaths and visualize yourself succeeding. 3) **Positive self-talk**: Replace 'I will fail' with 'I have prepared as well as I can.' 4) **Physical care**: Get good sleep the night before, eat a healthy meal, and stay hydrated. 5) **During the exam**: If you feel anxious, pause, take 3 deep breaths, and refocus. Remember, one exam does not define your worth or your future.";
}

// ========================================
// TIRED & BURNOUT INTENT HANDLERS
// ========================================

async function handleTired(session) {
  const dbResponse = await getResponseFromDatabase('tired', session);
  return dbResponse ? dbResponse.response :
    "😴 It sounds like you may need some rest. Being tired is often your body and mind asking for a pause. If possible, take a short break, drink some water, stretch a little, or rest your eyes. Even a small recharge can make a big difference. Remember, productivity is important — but your health and well-being come first.";
}

async function handleAlwaysTired(session) {
  const dbResponse = await getResponseFromDatabase('always_tired', session);
  return dbResponse ? dbResponse.response :
    "🩺 Feeling constantly tired despite adequate sleep can be caused by many factors: poor sleep quality, stress, depression, anemia, thyroid issues, nutritional deficiencies, or other medical conditions. I recommend: 1) Track your sleep patterns and quality. 2) Evaluate your diet and hydration. 3) Assess your stress levels and emotional health. 4) **See a doctor** for a checkup — chronic fatigue should be evaluated medically. You deserve to feel energized and well.";
}

async function handleHowToGetEnergy(session) {
  const dbResponse = await getResponseFromDatabase('how_to_get_energy', session);
  return dbResponse ? dbResponse.response :
    "⚡ Here are natural ways to boost energy: 1) **Hydrate**: Dehydration causes fatigue. Drink a glass of water. 2) **Move**: Even 5-10 minutes of stretching or walking increases blood flow. 3) **Healthy snacks**: Eat protein and complex carbs (nuts, fruit, whole grains). 4) **Power nap**: 15-20 minutes can refresh you without grogginess. 5) **Sunlight**: Natural light helps regulate energy levels. 6) **Deep breaths**: Oxygen boosts alertness. If fatigue persists, prioritize better sleep and consult a doctor.";
}

async function handleBurnout(session) {
  const dbResponse = await getResponseFromDatabase('burnout', session);
  return dbResponse ? dbResponse.response :
    "🔥 Burnout is serious — it is physical, emotional, and mental exhaustion caused by prolonged stress. Signs include feeling drained, cynical, less effective, and detached. To address burnout: 1) **Acknowledge it**: Recognizing burnout is the first step. 2) **Set boundaries**: Learn to say no and protect your time. 3) **Rest deeply**: Not just sleep, but true disconnection from work/stress. 4) **Seek support**: Talk to friends, family, or a counselor. 5) **Re-evaluate priorities**: Sometimes systems need to change, not just you. Burnout is not weakness — it is a sign you have been strong for too long without support.";
}


// ========================================
// POSITIVE EMOTIONS HANDLERS
// ========================================

async function handleFeelingHappy(session) {
  const dbResponse = await getResponseFromDatabase('feeling_happy', session);
  return dbResponse ? dbResponse.response :
    "🌟 That is wonderful to hear! Happiness is something to celebrate, even in small moments. Hold onto this positive energy and let it motivate you to keep moving forward. If something special happened today, I would love to hear about it. Positive moments like this can inspire even greater achievements ahead!";
}

async function handleGoodNewsCelebration(session) {
  const dbResponse = await getResponseFromDatabase('good_news_celebration', session);
  return dbResponse ? dbResponse.response :
    "🎉 That is amazing! Congratulations on your achievement! Your hard work and dedication paid off. Take a moment to really enjoy this success — you have earned it. This accomplishment shows what you are capable of, and I am confident you will achieve even more great things in the future!";
}

async function handleFeelingGrateful(session) {
  const dbResponse = await getResponseFromDatabase('feeling_grateful', session);
  return dbResponse ? dbResponse.response :
    "🙏 Gratitude is such a powerful emotion. Research shows that practicing gratitude improves mental health, strengthens relationships, and increases overall happiness. It is beautiful that you are taking time to appreciate the good things in your life. Keep holding onto that positive mindset — it will carry you through challenges when they arise.";
}

async function handleExcited(session) {
  const dbResponse = await getResponseFromDatabase('excited', session);
  return dbResponse ? dbResponse.response :
    "🎉 That is amazing! Excitement brings positive energy and motivation. Enjoy this moment and let it push you toward even greater achievements. Whatever you are looking forward to, I hope it turns out even better than you expect! Your enthusiasm is contagious!";
}

async function handlePreparingForEvent(session) {
  const dbResponse = await getResponseFromDatabase('preparing_for_event', session);
  return dbResponse ? dbResponse.response :
    "✨ How exciting! It sounds like something important is coming up. Here are some tips to prepare: 1) **Stay organized**: Make a checklist of what you need to do. 2) **Rest well**: Get good sleep the night before. 3) **Positive visualization**: Imagine yourself succeeding. 4) **Stay calm**: Remember your preparation and trust yourself. You are going to do great!";
}

async function handleNervousExcited(session) {
  const dbResponse = await getResponseFromDatabase('nervous_excited', session);
  return dbResponse ? dbResponse.response :
    "🦋 That is a perfectly normal combination! Nervous excitement means you care about the outcome and you are ready to take on a challenge. The butterflies you feel are your body preparing you to perform at your best. Channel that energy positively — take deep breaths, stay focused, and trust your preparation. You have got this!";
}


// ========================================
// LONELINESS INTENT HANDLERS
// ========================================

async function handleLonely(session) {
  const dbResponse = await getResponseFromDatabase('lonely', session);
  return dbResponse ? dbResponse.response :
    "🤍 I am really sorry you are feeling alone. Loneliness can feel heavy, but please remember that your feelings matter and you are not invisible. Sometimes reaching out to a friend, classmate, or family member can help more than you expect. Even small conversations can rebuild connection. You deserve support and understanding.";
}

async function handleHowToCopeWithLoneliness(session) {
  const dbResponse = await getResponseFromDatabase('how_to_cope_loneliness', session);
  return dbResponse ? dbResponse.response :
    "💬 Here are ways to address loneliness: 1) **Reach out**: Send a message to someone you have not talked to in a while. 2) **Join activities**: Clubs, classes, or volunteer work can create new connections. 3) **Online communities**: Find groups with shared interests. 4) **Be kind to yourself**: Loneliness does not mean you are unlikeable. 5) **Quality over quantity**: One meaningful connection is better than many shallow ones. 6) **Professional help**: If loneliness feels overwhelming, a therapist can help. Small steps toward connection can make a big difference.";
}

async function handleNoOneUnderstands(session) {
  const dbResponse = await getResponseFromDatabase('no_one_understands', session);
  return dbResponse ? dbResponse.response :
    "👂 Feeling misunderstood and unheard is deeply painful. Please know that your experiences and feelings are valid, even if others do not fully grasp them right now. Sometimes it helps to: 1) Express yourself clearly: 'I feel ___ when ___ because ___.' 2) Find your people: Seek out those with similar experiences or interests. 3) Be patient: Understanding takes time and effort from both sides. 4) Consider counseling: A therapist can provide the understanding and validation you need. You are not invisible, and you matter.";
}

async function handleFeelingLeftOut(session) {
  const dbResponse = await getResponseFromDatabase('feeling_left_out', session);
  return dbResponse ? dbResponse.response :
    "💔 Being left out hurts, and your feelings are completely valid. Remember: being excluded says nothing about your worth. Here is what might help: 1) **Initiate**: Invite people to do things with you. 2) **Expand your circle**: Try meeting new people through different activities. 3) **Self-reflection**: Sometimes incompatibility is not personal. 4) **Value yourself**: Your worth is not determined by others inclusion. 5) **Talk about it**: If appropriate, express your feelings to those involved. You deserve to feel included and valued.";
}


// ========================================
// CONFUSION INTENT HANDLERS
// ========================================

async function handleConfused(session) {
  const dbResponse = await getResponseFromDatabase('confused', session);
  return dbResponse ? dbResponse.response :
    "🤔 It is completely normal to feel confused when things are unclear. Try breaking the issue into smaller parts and focus on one detail at a time. If you explain what is confusing you, I can try to clarify it step by step. Clarity often comes with patience and careful thinking. What specifically is unclear?";
}

async function handleDontKnowWhatToDo(session) {
  const dbResponse = await getResponseFromDatabase('dont_know_what_to_do', session);
  return dbResponse ? dbResponse.response :
    "🧭 Feeling lost or stuck is a common experience. Here is how to find direction: 1) **Pause and breathe**: Clarity comes when you are calm. 2) **Identify what you know**: Even small certainties can guide you. 3) **Break it down**: What is one small step you could take today? 4) **Ask for input**: Talk to someone you trust for perspective. 5) **Give yourself grace**: Not having all the answers is okay. 6) **Explore options**: Sometimes you need to try things to find the right path. You do not need to have everything figured out right now.";
}

async function handleNeedExplanation(session) {
  const dbResponse = await getResponseFromDatabase('need_explanation', session);
  return dbResponse ? dbResponse.response :
    "📖 Of course! I would be happy to help explain. Please tell me: 1) What topic or concept are you trying to understand? 2) What part is confusing? 3) What have you already tried to figure it out? The more details you share, the better I can tailor my explanation to help you understand clearly.";
}


// ========================================
// ANGER INTENT HANDLERS
// ========================================

async function handleAngry(session) {
  const dbResponse = await getResponseFromDatabase('angry', session);
  return dbResponse ? dbResponse.response :
    "🔥 Anger is a strong emotion, and it often signals that something feels unfair or upsetting. Before reacting, take a deep breath and give yourself a moment to cool down. Responding calmly can prevent regret later. If you would like to share what happened, I am here to listen without judgment.";
}

async function handleHowToCalmAnger(session) {
  const dbResponse = await getResponseFromDatabase('how_to_calm_anger', session);
  return dbResponse ? dbResponse.response :
    "🌬️ Here are immediate anger management techniques: 1) **Step away**: Remove yourself from the situation temporarily. 2) **Deep breathing**: Slow, deep breaths activate your calming response. 3) **Count to 10 (or 100)**: Give yourself time before reacting. 4) **Physical release**: Go for a walk, exercise, or punch a pillow. 5) **Write it out**: Express your feelings on paper instead of lashing out. 6) **Address it later**: Once calm, discuss the issue constructively. Remember, feeling anger is normal — it is how you express it that matters.";
}

async function handleAngryAtSomeone(session) {
  const dbResponse = await getResponseFromDatabase('angry_at_someone', session);
  return dbResponse ? dbResponse.response :
    "😤 It is natural to feel angry when someone hurts or upsets you. Here is what might help: 1) **Cool off first**: Do not respond while emotions are high. 2) **Identify the real issue**: What specifically hurt you? 3) **Communicate clearly**: Use 'I feel ___ when you ___ because ___' statements. 4) **Set boundaries**: Decide what behavior you will and will not accept. 5) **Evaluate the relationship**: Is this person usually respectful? 6) **Forgive (when ready)**: Holding anger hurts you more than them. Your feelings are valid, and you deserve respectful treatment.";
}


// ========================================
// FRUSTRATION INTENT HANDLERS
// ========================================

async function handleFrustrated(session) {
  const dbResponse = await getResponseFromDatabase('frustrated', session);
  return dbResponse ? dbResponse.response :
    "⚡ Frustration usually happens when effort does not immediately bring results. That does not mean you are failing — it simply means the process needs adjustment. Take a short break, rethink your approach, and try again with a fresh mindset. Progress is often built through small, repeated efforts. You are closer than you think.";
}

async function handleNothingIsWorking(session) {
  const dbResponse = await getResponseFromDatabase('nothing_is_working', session);
  return dbResponse ? dbResponse.response :
    "🔄 Repeated setbacks are incredibly frustrating. But remember: failure is not the opposite of success; it is part of the process. Here is what to do: 1) **Step back**: Take a break and return with fresh eyes. 2) **Analyze**: What is not working? What could you change? 3) **Ask for help**: Sometimes a new perspective reveals the solution. 4) **Celebrate effort**: You are trying, and that matters. 5) **Adjust strategy**: Maybe there is a different approach. Every successful person has faced failure many times. Keep going — breakthroughs often come right when you want to give up.";
}

async function handleTechFrustration(session) {
  const dbResponse = await getResponseFromDatabase('tech_frustration', session);
  return dbResponse ? dbResponse.response :
    "💻 Technology frustration is very real! Here is what to try: 1) **Restart**: Turn it off and back on (seriously, this fixes many issues). 2) **Check connections**: Ensure cables, Wi-Fi, and power are working. 3) **Update**: Sometimes outdated software causes problems. 4) **Google the error**: Someone else likely faced the same issue. 5) **Take a break**: Walk away for 10 minutes and try again. 6) **Ask for help**: IT support, tech-savvy friends, or online forums. You will figure it out!";
}

async function handleFrustratedWithSelf(session) {
  const dbResponse = await getResponseFromDatabase('frustrated_with_self', session);
  return dbResponse ? dbResponse.response :
    "💙 Being frustrated with yourself is painful. Please remember: You are human, and humans make mistakes, struggle, and learn. Self-compassion is not weakness — it is strength. Ask yourself: Would you speak this harshly to a friend? Probably not. Treat yourself with the same kindness. 1) **Acknowledge the feeling**: 'I am frustrated, and that is okay.' 2) **Learn from it**: 'What can I do differently next time?' 3) **Forgive yourself**: Everyone deserves grace, including you. You are doing better than you think.";
}

//--------------------------Above Functions for responses--------
//--------------------------Above Functions for responses--------
//--------------------------Above Functions for responses--------
//--------------------------Above Functions for responses--------



// ========== MAIN INTENT ROUTER ==========
async function handleIntent(intent, entities, session, message) {
  const startTime = Date.now();
  let response;
  
  try {
    // ✅ STEP 1: Check database FIRST for any static responses
    try {
      const dbResponse = await getResponseFromDatabase(intent, session, entities);
      if (dbResponse && dbResponse.response) {
        console.log(`📊 Using DB response for intent: ${intent}`);
        return { 
          response: dbResponse.response, 
          responseTime: Date.now() - startTime,
          source: 'database'
        };
      }
    } catch (dbErr) {
      console.warn('⚠️  DB lookup issue, continuing to handlers:', dbErr.message);
    }
    
    // ✅ STEP 2: Mental health check (ALWAYS CHECK FIRST)
    const mentalHealthConcern = detectMentalHealthConcern(message);
    if (mentalHealthConcern) {
      response = handleMentalHealthConcern(mentalHealthConcern, session);
      return { response, responseTime: Date.now() - startTime, source: 'handler' };
    }
    
    // ✅ STEP 3: Check casual questions
    const casual = detectCasualQuestion(message);
    if (casual === 'greeting') {
      // Check DB first for greeting
      const dbGreeting = await getResponseFromDatabase('greeting', session, entities);
      response = dbGreeting ? dbGreeting.response : "Hey there! 👋 How can I help you?";
      return { response, responseTime: Date.now() - startTime, source: dbGreeting ? 'database' : 'fallback' };
    }
    if (casual === 'casual_greeting') {
      const dbResp = await getResponseFromDatabase('casual_greeting', session, entities);
      response = dbResp ? dbResp.response : "I'm doing great! How can I help?";
      return { response, responseTime: Date.now() - startTime, source: dbResp ? 'database' : 'fallback' };
    }
    if (casual === 'user_info') {
      response = handleUserInfo(session);
      return { response, responseTime: Date.now() - startTime, source: 'handler' };
    }
    if (casual === 'developers_info') {
      const dbResp = await getResponseFromDatabase('developers_info', session, entities);
      response = dbResp ? dbResp.response : "Campus Entry Guide was developed by CS students!";
      return { response, responseTime: Date.now() - startTime, source: dbResp ? 'database' : 'fallback' };
    }
    
    // ✅ STEP 4: Route to dynamic intent handlers (these need user data)
    switch (intent) {
        case 'feeling_sad':
      return await handleFeelingSad(session);
    
    case 'why_am_i_sad':
      return await handleWhyAmISad(session);
    
    case 'how_to_stop_sadness':
      return await handleHowToStopSadness(session);
    
    case 'want_to_cry':
      return await handleWantToCry(session);
    
    case 'am_i_depressed':
      return await handleAmIDepressed(session);
    
    case 'feeling_empty':
      return await handleFeelingEmpty(session);
    
    case 'sad_no_reason':
      return await handleSadNoReason(session);
    
    case 'feeling_worthless':
      return await handleFeelingWorthless(session);
    
    
    // ============ STRESS & ANXIETY INTENTS ============
    case 'stressed':
      return await handleStressed(session);
    
    case 'how_to_reduce_stress':
      return await handleHowToReduceStress(session);
    
    case 'overwhelmed_tasks':
      return await handleOverwhelmedTasks(session);
    
    case 'stress_physical_symptoms':
      return await handleStressPhysicalSymptoms(session);
    
    case 'nervous':
      return await handleNervous(session);
    
    case 'how_to_calm_anxiety':
      return await handleHowToCalmAnxiety(session);
    
    case 'panic_attack':
      return await handlePanicAttack(session);
    
    case 'worried_about_future':
      return await handleWorriedAboutFuture(session);
    
    case 'exam_anxiety':
      return await handleExamAnxiety(session);
    
    
    // ============ TIRED & BURNOUT INTENTS ============
    case 'tired':
      return await handleTired(session);
    
    case 'always_tired':
      return await handleAlwaysTired(session);
    
    case 'how_to_get_energy':
      return await handleHowToGetEnergy(session);
    
    case 'burnout':
      return await handleBurnout(session);
    
    
    // ============ POSITIVE EMOTIONS ============
    case 'feeling_happy':
      return await handleFeelingHappy(session);
    
    case 'good_news_celebration':
      return await handleGoodNewsCelebration(session);
    
    case 'feeling_grateful':
      return await handleFeelingGrateful(session);
    
    case 'excited':
      return await handleExcited(session);
    
    case 'preparing_for_event':
      return await handlePreparingForEvent(session);
    
    case 'nervous_excited':
      return await handleNervousExcited(session);
    
    
    // ============ LONELINESS INTENTS ============
    case 'lonely':
      return await handleLonely(session);
    
    case 'how_to_cope_loneliness':
      return await handleHowToCopeWithLoneliness(session);
    
    case 'no_one_understands':
      return await handleNoOneUnderstands(session);
    
    case 'feeling_left_out':
      return await handleFeelingLeftOut(session);
    
    
    // ============ CONFUSION INTENTS ============
    case 'confused':
      return await handleConfused(session);
    
    case 'dont_know_what_to_do':
      return await handleDontKnowWhatToDo(session);
    
    case 'need_explanation':
      return await handleNeedExplanation(session);
    
    
    // ============ ANGER INTENTS ============
    case 'angry':
      return await handleAngry(session);
    
    case 'how_to_calm_anger':
      return await handleHowToCalmAnger(session);
    
    case 'angry_at_someone':
      return await handleAngryAtSomeone(session);
    
    
    // ============ FRUSTRATION INTENTS ============
    case 'frustrated':
      return await handleFrustrated(session);
    
    case 'nothing_is_working':
      return await handleNothingIsWorking(session);
    
    case 'tech_frustration':
      return await handleTechFrustration(session);
    
    case 'frustrated_with_self':
      return await handleFrustratedWithSelf(session);
    
    
    // ============ EXISTING INTENTS ============
    case 'greeting':
      return await handleGreeting(session);
    
    case 'how_are_you':
      return await handleHowAreYou(session);
    
    case 'goodbye':
      return await handleGoodbye(session);
    
    case 'good_night':
      return await handleGoodNight(session);
    
    case 'thanks':
      return await handleThanks(session);
    
    case 'sorry':
      return await handleSorry(session);
    
    case 'help':
      return await handleHelp(session);
    
    case 'joke':
      return await handleJoke(session);
    
    case 'motivation':
      return await handleMotivation(session);
    
    case 'abusive_language':
      return await handleAbusiveLanguage(session);

      case 'greeting':
    response = await handleGreeting(session);
    break;

  case 'how_are_you':
    response = await handleHowAreYou(session);
    break;

  case 'bot_name':
    response = await handleBotName(session);
    break;

  case 'friend_request':
    response = await handleFriendRequest(session);
    break;

  case 'love_expression':
    response = await handleLoveExpression(session);
    break;

  case 'abusive_language':
    response = await handleAbusiveLanguage(session);
    break;

  case 'thanks':
    response = await handleThanks(session);
    break;

      case 'university_location':
    response = await handleUniversityLocation(session);
    break;

  case 'career_services':
    response = await handleCareerServices(session);
    break;

  case 'student_services':
    response = await handleStudentServices(session);
    break;

  case 'library_membership':
    response = await handleLibraryMembership(session);
    break;

      case 'medical_services':
    response = await handleMedicalServices(session);
    break;

  case 'emergency_contacts':
    response = await handleEmergencyContacts(session);
    break;

  case 'developers_info':
    response = await handleDevelopersInfo(session);
    break;

  case 'chatbot_usage':
    response = await handleChatbotUsage(session);
    break;

      case 'fee_structure_info':
    response = await handleFeeStructure(session);
    break;

  case 'transport_info':
    response = await handleTransportInfo(session);
    break;

  case 'fee_concession_info':
    response = await handleFeeConcession(session);
    break;

      case 'campus_facilities':
    response = await handleCampusFacilities(session);
    break;

  case 'cafeteria_info':
    response = await handleCafeteriaInfo(session);
    break;

  case 'wifi_info':
    response = await handleWiFiInfo(session);
    break;

  case 'gym_info':
    response = await handleGymInfo(session);
    break;

  case 'sports_info':
    response = await handleSportsInfo(session);
    break;

       case 'cs_programs':
    response = await handleCSPrograms(session);
    break;

  case 'agriculture_programs':
    response = await handleAgriculturePrograms(session);
    break;

  case 'business_programs':
    response = await handleBusinessPrograms(session);
    break;

  case 'veterinary_programs':
    response = await handleVeterinaryPrograms(session);
    break;

      case 'admissions_info':
  response = await handleAdmissionsInfo(session);
  break;

      case 'exam_info':
  response = await handleExamInfo(session);
  break;

      case 'university_departments':
  response = await handleUniversityDepartments(session);
  break;


      case 'university_info':
  response = await handleUniversityInfo(session);
  break;

      case 'grading_system':
      response = await handleGradingSystem(session);
      break;

    case 'exam_policies':
  response = await handleExamPolicies(session);
  break;

    case 'credit_hours_system':
    case 'credit_hours_info':
      response = await handleCreditHoursSystem(session);
      break;

    case 'how_to_apply_admission':
      response = await handleHowToApply(session);
      break;

    case 'admission_eligibility':
      response = await handleAdmissionEligibility(session);
      break;

    case 'admission_schedule':
      response = await handleAdmissionSchedule(session);
      break;

    case 'step_by_step_admission':
      response = await handleStepByStepAdmission(session);
      break;

    case 'my_schedule_today':
    response = await handleMyScheduleToday(session, entities);
    break;
  //-------------------------------------Above all the insertion reponse and intent switch added perfect------------
  
  case 'my_schedule_tomorrow':
    response = await handleMyScheduleTomorrow(session, entities);
    break;
  
  case 'my_schedule_day':
    response = await handleMyScheduleDay(session, entities);
    break;
  
  case 'my_next_class':
    response = await handleMyNextClass(session, entities);
    break;
  
  case 'class_at_time':
    response = await handleClassAtTime(session, entities);
    break;
  
  // TEACHER & CONTACT
  case 'teacher_info':
    response = await handleTeacherInfo(session, entities, message);
    break;
  
  case 'teacher_contact':
    response = await handleTeacherContact(session, entities, message);
    break;
  
  case 'teacher_office_location':
    response = await handleTeacherOfficeLocation(session);
    break;
  
  // COMPLAINTS
  case 'my_complaints':
  case 'recent_complaints':
    response = await handleMyComplaints(session);
    break;
  
  case 'complaint_filing':
  case 'how_to_file_complaint':
    response = await handleComplaintFiling(session);
    break;
  
  // ANNOUNCEMENTS
  case 'my_announcements':
    response = await handleMyAnnouncements(session);
    break;
  
  case 'unread_announcements':
    response = await handleUnreadAnnouncements(session);
    break;
  
  // EXAMS & RESULTS
  case 'exam_info':
    response = await handleExamInfo(session, entities, message);
    break;
  
  case 'result_checking':
  case 'how_to_check_result':
    response = await handleResultChecking(session);
    break;
  
  // ADMINISTRATION
  case 'administration_contact':
  case 'contact_administration':
    response = await handleAdministrationContact(session);
    break;

  case 'attendance_policy':
  response = await handleAttendancePolicy(session);
  break;

  // FINANCE
  case 'fee_concession':
  case 'concession_available':
    response = await handleFeeConcession(session);
    break;
  
  case 'payment_method':
    response = await handlePaymentMethod(session);
    break;
  
  case 'hec_scholarship':
    response = await handleHECScholarship(session);
    break;
  
  case 'merit_scholarship':
    response = await handleMeritScholarship(session);
    break;
  
  case 'admissions_info':
    response = await handleAdmissionsInfo(session);
    break;
  
  case 'exam_info':
    response = await handleExamInfo(session);
    break;
  
  case 'graduate_fee':
    response = await handleGraduateFee(session);
    break;
  
  case 'undergraduate_fee':
    response = await handleUndergraduateFee(session);
    break;
  
  case 'admission_criteria':
    response = await handleAdmissionCriteria(session);
    break;
  
  case 'admission_process':
    response = await handleAdmissionProcess(session);
    break;
  
  case 'admission_dates':
    response = await handleAdmissionDates(session);
    break;
  
  case 'vice_chancellor_info':
    response = await handleViceChancellorInfo(session);
    break;
  
  case 'available_faculties':
    response = await handleAvailableFaculties(session);
    break;
  
  case 'it_programs':
    response = await handleITProgramsInfo(session);
    break;
  
  case 'business_programs':
    response = await handleBusinessProgramsInfo(session);
    break;
  
  case 'university_history':
    response = await handleUniversityHistory(session);
    break;
  
  case 'university_location':
    response = await handleUniversityLocation(session);
    break;
  
  // DEFAULT
  default:
    response = await handleDefault(session);
    
    const isStudent = session.user_role === 'Student';
    response = isStudent 
      ? `I'm not sure about that. Try asking about:\n\n📅 Your schedule\n👨‍🏫 Teachers\n📢 Announcements\n🎓 University info\n\nType "help" for all features! 😊`
      : `I'm not sure about that. Try:\n\n📅 Your classes\n📢 Announcements\n🎓 University info\n\nType "help" for all features! 😊`;
}
    
    return { response, responseTime: Date.now() - startTime, source: 'handler' };
    
  } catch (error) {
    console.error('❌ Intent handler error:', error);
    return {
      response: "Sorry, I encountered an issue. Please try again.",
      responseTime: Date.now() - startTime,
      source: 'error'
    };
  }
}

// ========== SESSION MANAGEMENT ==========

async function getOrCreateSession(userId, userRole, sessionId) {
  return new Promise((resolve, reject) => {
    if (sessionId) {
      // SECURITY: Validate session belongs to this user
      const sql = `
        SELECT * FROM chatbot_conversations 
        WHERE session_id = ? AND user_id = ? AND user_role = ? AND is_active = 1
      `;
      
      db.query(sql, [sessionId, userId, userRole], (err, results) => {
        if (err) {
          reject(err);
          return;
        }
        
        if (results.length > 0) {
          db.query(
            'UPDATE chatbot_conversations SET last_activity = NOW() WHERE id = ?',
            [results[0].id]
          );
          console.log(`✅ Session validated for user ${userId}`);
          resolve(results[0]);
        } else {
          console.log(`⚠️ Invalid session for user ${userId} - creating new`);
          const newSessionId = `${userRole}_${userId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
          createNewSession(userId, userRole, newSessionId, resolve, reject);
        }
      });
    } else {
      const newSessionId = `${userRole}_${userId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      createNewSession(userId, userRole, newSessionId, resolve, reject);
    }
  });
}



function createNewSession(userId, userRole, sessionId, resolve, reject) {
  const table = userRole === 'Student' ? 'student_registration' : 'teacher_registration';
  
  db.query(`SELECT * FROM ${table} WHERE id = ?`, [userId], (err, userResults) => {
    if (err) {
      reject(err);
      return;
    }
    
    if (userResults.length === 0) {
      reject(new Error('User not found'));
      return;
    }
    
    const user = userResults[0];
    const contextData = {
      lastIntent: null,
      lastEntities: {},
      messageCount: 0
    };
    
    const insertData = {
      user_id: userId,
      user_role: userRole,
      session_id: sessionId,
      user_name: user.full_name,
      context_data: JSON.stringify(contextData)
    };
    
    if (userRole === 'Student') {
      insertData.user_degree = user.degree;
      insertData.user_section = user.section;
      insertData.user_semester = user.semester_no;
    } else if (userRole === 'Teacher') {
      insertData.user_department = user.department;
    }
    
    db.query(
      'INSERT INTO chatbot_conversations SET ?',
      insertData,
      (insertErr, result) => {
        if (insertErr) {
          reject(insertErr);
          return;
        }
        
        insertData.id = result.insertId;
        resolve(insertData);
      }
    );
  });
}

// ========== SUGGESTION GENERATOR - ROLE BASED ==========

function generateSuggestions(intent, session) {
  const suggestions = [];
  const isStudent = session.user_role === 'Student';
  
  switch (intent) {
    case 'greeting':
      if (isStudent) {
        suggestions.push('Classes today?');
        suggestions.push('Next class?');
        suggestions.push('Any announcements?');
        suggestions.push('My schedule for tomorrow?');
      } else {
        suggestions.push('My classes today?');
        suggestions.push('Tomorrow\'s schedule?');
        suggestions.push('Recent announcements');
      }
      break;
    
    case 'my_schedule_today':
    case 'my_schedule_day':
      suggestions.push('Next class?');
      suggestions.push('Am I free at 2 PM?');
      suggestions.push('Any announcements?');
      break;
      
    case 'exam_info':
      suggestions.push('My schedule today');
      if (isStudent) {
        suggestions.push('Fee structure');
        suggestions.push('Scholarship info');
      } else {
        suggestions.push('University info');
      }
      break;
      
    case 'university_info':
      suggestions.push('About departments');
      suggestions.push('Admission process');
      suggestions.push('Campus facilities');
      break;
      
    case 'admissions_info':
      suggestions.push('Fee structure');
      suggestions.push('Scholarship info');
      suggestions.push('Available programs');
      break;
    
    case 'my_announcements':
    case 'unread_announcements':
      suggestions.push('My schedule today');
      suggestions.push('My complaints');
      if (isStudent) {
        suggestions.push('Exam information');
      }
      break;
    
    case 'my_complaints':
      suggestions.push('Recent announcements');
      suggestions.push('My schedule');
      suggestions.push('How to file complaint?');
      break;
    
    case 'teacher_info':
      if (isStudent) {
        suggestions.push('My next class');
        suggestions.push('My schedule');
        suggestions.push('Any announcements?');
      }
      break;
    
    default:
      if (isStudent) {
        suggestions.push('My schedule today');
        suggestions.push('Next class?');
        suggestions.push('Any announcements?');
        suggestions.push('University info');
      } else {
        suggestions.push('My classes today');
        suggestions.push('Recent announcements');
        suggestions.push('Campus facilities');
      }
  }
  
  return suggestions;
}

// ========== API ENDPOINTS ==========

app.post("/chatbot-query", async (req, res) => {
  const { userId, userRole, message, sessionId, userFullName } = req.body;
  
  console.log(`💬 Chatbot: ${userRole} ${userId}: "${message}"`);
  
  if (!userId || !userRole || !message) {
    return res.status(400).json({ message: "Missing required fields" });
  }
  
  try {
    const session = await getOrCreateSession(userId, userRole, sessionId);
    const entities = extractEntities(message, session);
    
    const intentResult = await recognizeIntent(message, entities);
    console.log(`🎯 Intent: ${intentResult.intent} (${intentResult.confidence.toFixed(2)})`);
    
    // ✅ CHANGE: Get response AND responseSource
    const { response, responseTime, source } = await handleIntent(
      intentResult.intent,
      entities,
      session,
      message
    );
    
    // Save message to database
    let messageId = null;
    const messageData = {
      conversation_id: session.id,
      message: message,
      response: response,
      intent: intentResult.intent,
      confidence: intentResult.confidence,
      entities: JSON.stringify(entities),
      response_time_ms: responseTime,
      response_source: source || 'handler'  // ✅ FIXED - Use source from handleIntent return
    };
    
    db.query('INSERT INTO chatbot_messages SET ?', messageData, (err, result) => {
      if (err) console.error('❌ Save error:', err);
      else messageId = result.insertId;
    });
    
    const suggestions = generateSuggestions(intentResult.intent, session);
    
    res.status(200).json({
      message: "Success",
      response: response,
      intent: intentResult.intent,
      confidence: intentResult.confidence,
      entities: entities,
      sessionId: session.session_id,
      suggestions: suggestions,
      responseTime: responseTime,
      messageId: messageId
    });
    
  } catch (error) {
    console.error(`❌ [${requestId}] Chatbot error:`, error);
    
    // Return helpful message to user
    res.status(500).json({
      message: "Error processing request",
      response: `Sorry, I'm having trouble. 😅\n\nPlease:\n• Check internet\n• Rephrase question\n• Try again`,
      error: error.message
    });
}
});

app.post("/get-chatbot-history", (req, res) => {
  const { sessionId, userId, userRole, limit } = req.body;
  
  // SECURITY: Require all fields
  if (!sessionId || !userId || !userRole) {
    return res.status(400).json({ 
      message: "Missing required fields",
      error: "sessionId, userId, and userRole are required"
    });
  }
  
  // SECURITY: Validate ownership
  const sql = `
    SELECT cm.* FROM chatbot_messages cm
    JOIN chatbot_conversations cc ON cm.conversation_id = cc.id
    WHERE cc.session_id = ? 
      AND cc.user_id = ? 
      AND cc.user_role = ?
    ORDER BY cm.created_at DESC 
    LIMIT ?
  `;
  
  db.query(sql, [sessionId, userId, userRole, limit || 50], (err, results) => {
    if (err) {
      console.error('❌ History error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    console.log(`✅ Retrieved ${results.length} messages for user ${userId}`);
    
    res.status(200).json({
      message: "Success",
      history: results.reverse()
    });
  });
});

app.post("/clear-chatbot-conversation", (req, res) => {
  const { sessionId, userId, userRole } = req.body;
  
  // SECURITY: Require all fields
  if (!sessionId || !userId || !userRole) {
    return res.status(400).json({ 
      message: "Missing required fields",
      error: "sessionId, userId, and userRole are required"
    });
  }
  
  // SECURITY: Delete only user's own messages
  db.query(
    `DELETE cm FROM chatbot_messages cm 
     JOIN chatbot_conversations cc ON cm.conversation_id = cc.id 
     WHERE cc.session_id = ? AND cc.user_id = ? AND cc.user_role = ?`,
    [sessionId, userId, userRole],
    (err) => {
      if (err) console.error('❌ Delete messages error:', err);
    }
  );
  
  // SECURITY: Delete only user's own conversation
  db.query(
    'DELETE FROM chatbot_conversations WHERE session_id = ? AND user_id = ? AND user_role = ?',
    [sessionId, userId, userRole],
    (err, result) => {
      if (err) {
        console.error('❌ Clear error:', err);
        return res.status(500).json({ message: "Error", error: err.message });
      }
      
      console.log(`🗑️ Cleared conversation for user ${userId}`);
      res.status(200).json({ message: "Conversation cleared successfully" });
    }
  );
});

app.get("/get-common-questions", (req, res) => {
  const { userRole } = req.query;
  
  let sql = `
    SELECT * FROM chatbot_common_questions 
    WHERE is_active = 1
  `;
  
  if (userRole === 'Student') {
    sql += ` AND (target_role = 'Student' OR target_role = 'All')`;
  } else if (userRole === 'Teacher') {
    sql += ` AND (target_role = 'Teacher' OR target_role = 'All')`;
  }
  
  sql += ` ORDER BY category, display_order`;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Questions error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    // Group by category
    const grouped = results.reduce((acc, q) => {
      if (!acc[q.category]) {
        acc[q.category] = [];
      }
      acc[q.category].push(q);
      return acc;
    }, {});
    
    res.status(200).json({
      message: "Success",
      questions: grouped
    });
  });
});

app.post("/submit-chatbot-feedback", (req, res) => {
  const { messageId, userId, userRole, rating, feedbackText } = req.body;
  
  if (!messageId || !userId || !rating) {
    return res.status(400).json({ message: "Missing required fields" });
  }
  
  const feedbackData = {
    message_id: messageId,
    user_id: userId,
    user_role: userRole,
    rating: rating,
    feedback_text: feedbackText || null
  };
  
  db.query('INSERT INTO chatbot_feedback SET ?', feedbackData, (err, result) => {
    if (err) {
      console.error('❌ Feedback error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    console.log(`⭐ Feedback received: ${rating}/5 from ${userRole} ${userId}`);
    res.status(201).json({
      message: "Feedback saved successfully",
      feedbackId: result.insertId
    });
  });
});

// Auto-cleanup old conversations (runs every hour)
setInterval(() => {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  
  // Delete old messages
  db.query(
    'DELETE cm FROM chatbot_messages cm JOIN chatbot_conversations cc ON cm.conversation_id = cc.id WHERE cc.last_activity < ?',
    [oneDayAgo],
    (err) => {
      if (err) console.error("❌ Cleanup messages error:", err);
    }
  );
  
  // Delete old conversations
  db.query(
    'DELETE FROM chatbot_conversations WHERE last_activity < ?',
    [oneDayAgo],
    (err, result) => {
      if (err) {
        console.error("❌ Cleanup error:", err);
      } else if (result.affectedRows > 0) {
        console.log(`🗑️ Cleaned ${result.affectedRows} old conversations (>24hrs)`);
      }
    }
  );
}, 60 * 60 * 1000); // Run every hour


// GET: Retrieve single response
app.get("/admin/response/:intentName", (req, res) => {
  const { intentName } = req.params;
  
  const sql = `
    SELECT * FROM chatbot_responses 
    WHERE intent_name = ? 
    LIMIT 1
  `;
  
  db.query(sql, [intentName], (err, results) => {
    if (err) {
      console.error('❌ Fetch error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    if (results.length === 0) {
      return res.status(404).json({ message: "Response not found" });
    }
    
    res.status(200).json({
      message: "Success",
      response: results[0]
    });
  });
});

// POST: Update/Create response
app.post("/admin/update-response", (req, res) => {
  const { intentName, question, response, category, targetRole, responseType, notes } = req.body;
  // TODO: Add authentication check here!
  
  if (!intentName || !response) {
    return res.status(400).json({ message: "Missing required fields: intentName, response" });
  }
  
  // Check if exists
  const checkSql = `SELECT id FROM chatbot_responses WHERE intent_name = ?`;
  
  db.query(checkSql, [intentName], (checkErr, checkResults) => {
    if (checkErr) {
      console.error('❌ Check error:', checkErr);
      return res.status(500).json({ message: "Error", error: checkErr.message });
    }
    
    if (checkResults.length > 0) {
      // UPDATE
      const updateSql = `
        UPDATE chatbot_responses 
        SET response = ?, 
            question = ?, 
            category = ?, 
            target_role = ?, 
            response_type = ?,
            notes = ?,
            updated_at = NOW()
        WHERE intent_name = ?
      `;
      
      db.query(
        updateSql,
        [response, question || '', category || '', targetRole || 'All', responseType || 'static', notes || '', intentName],
        (updateErr, updateResult) => {
          if (updateErr) {
            console.error('❌ Update error:', updateErr);
            return res.status(500).json({ message: "Error", error: updateErr.message });
          }
          
          console.log(`✅ Updated response for intent: ${intentName}`);
          res.status(200).json({ 
            message: "Response updated successfully",
            intentName: intentName,
            action: 'update'
          });
        }
      );
    } else {
      // INSERT
      const insertSql = `
        INSERT INTO chatbot_responses 
        (intent_name, question, response, category, target_role, response_type, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `;
      
      db.query(
        insertSql,
        [intentName, question || '', response, category || '', targetRole || 'All', responseType || 'static', notes || ''],
        (insertErr, insertResult) => {
          if (insertErr) {
            if (insertErr.code === 'ER_DUP_ENTRY') {
              return res.status(409).json({ message: "Intent already exists" });
            }
            console.error('❌ Insert error:', insertErr);
            return res.status(500).json({ message: "Error", error: insertErr.message });
          }
          
          console.log(`✅ Created new response for intent: ${intentName}`);
          res.status(201).json({ 
            message: "Response created successfully",
            intentName: intentName,
            action: 'create'
          });
        }
      );
    }
  });
});

// GET: All responses (Admin Dashboard)
app.get("/admin/all-responses", (req, res) => {
  const sql = `
    SELECT id, intent_name, question, category, target_role, response_type, is_active, created_at, updated_at
    FROM chatbot_responses 
    ORDER BY category ASC, intent_name ASC
  `;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Fetch error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    // Group by category
    const grouped = results.reduce((acc, item) => {
      if (!acc[item.category]) {
        acc[item.category] = [];
      }
      acc[item.category].push(item);
      return acc;
    }, {});
    
    res.status(200).json({
      message: "Success",
      totalResponses: results.length,
      byCategory: grouped,
      responses: results
    });
  });
});

// GET: Responses by category
app.get("/admin/responses-by-category/:category", (req, res) => {
  const { category } = req.params;
  
  const sql = `
    SELECT * FROM chatbot_responses 
    WHERE category = ? 
    ORDER BY intent_name ASC
  `;
  
  db.query(sql, [category], (err, results) => {
    if (err) {
      console.error('❌ Fetch error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    res.status(200).json({
      message: "Success",
      category: category,
      totalResponses: results.length,
      responses: results
    });
  });
});

// POST: Bulk update responses
app.post("/admin/bulk-update-responses", (req, res) => {
  const { updates } = req.body; // Array of {intentName, response, ...}
  // TODO: Add authentication
  
  if (!Array.isArray(updates) || updates.length === 0) {
    return res.status(400).json({ message: "Invalid updates array" });
  }
  
  let completed = 0;
  let failed = 0;
  const errors = [];
  
  updates.forEach((update, index) => {
    const sql = `
      UPDATE chatbot_responses 
      SET response = ?, notes = ?, updated_at = NOW()
      WHERE intent_name = ?
    `;
    
    db.query(
      sql,
      [update.response, update.notes || '', update.intentName],
      (err, result) => {
        if (err) {
          failed++;
          errors.push({ intent: update.intentName, error: err.message });
        } else {
          completed++;
        }
        
        // When all queries done
        if (completed + failed === updates.length) {
          console.log(`✅ Bulk update: ${completed} success, ${failed} failed`);
          res.status(200).json({
            message: "Bulk update completed",
            successful: completed,
            failed: failed,
            errors: errors.length > 0 ? errors : null
          });
        }
      }
    );
  });
});

// DELETE: Deactivate response
app.delete("/admin/deactivate-response/:intentName", (req, res) => {
  const { intentName } = req.params;
  // TODO: Add authentication
  
  const sql = `
    UPDATE chatbot_responses 
    SET is_active = 0
    WHERE intent_name = ?
  `;
  
  db.query(sql, [intentName], (err, result) => {
    if (err) {
      console.error('❌ Delete error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Response not found" });
    }
    
    console.log(`✅ Deactivated response: ${intentName}`);
    res.status(200).json({ 
      message: "Response deactivated successfully",
      intentName: intentName
    });
  });
});

// GET: Analytics - Response usage
app.get("/admin/response-analytics", (req, res) => {
  const sql = `
    SELECT 
      intent,
      COUNT(*) as total_uses,
      AVG(response_time_ms) as avg_response_time,
      AVG(confidence) as avg_confidence,
      response_source,
      DATE(created_at) as date
    FROM chatbot_messages
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    GROUP BY intent, response_source, DATE(created_at)
    ORDER BY date DESC, total_uses DESC
  `;
  
  db.query(sql, (err, results) => {
    if (err) {
      console.error('❌ Analytics error:', err);
      return res.status(500).json({ message: "Error", error: err.message });
    }
    
    res.status(200).json({
      message: "Success",
      period: "Last 30 days",
      analytics: results
    });
  });
});

console.log("✅ Enhanced Chatbot System Ready with Role-Based Responses");
console.log("   - Student & Teacher specific responses");
console.log("   - User-specific data fetching");
console.log("   - Natural Language Processing");
console.log("   - Multilingual support (English + Urdu)");
console.log("   - Mental health support");
console.log("   - Auto-cleanup (24hrs)");

//--------------------------------End Of Chatbot Points--------------------
//--------------------------------End Of Chatbot Points--------------------
//--------------------------------End Of Chatbot Points--------------------





//--------------------Mp End Points--------------------------
//--------------------Mp End Points--------------------------
// Helper: distance between two GPS coords (Haversine)
function calculateDistanceBetweenPoints(lat1, lon1, lat2, lon2) {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── BOUNDARIES ──────────────────────────────────────────────────────────────
app.get('/api/campus-map/boundaries/:campusType', (req, res) => {
    const { campusType } = req.params;
    db.query(
        `SELECT latitude, longitude, point_order
         FROM campus_boundaries
         WHERE campus_type = ?
         ORDER BY point_order ASC`,
        [campusType],
        (err, boundaries) => {
            if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            if (boundaries.length === 0)
                return res.status(404).json({ success: false, message: 'Campus boundaries not found' });

            const lats = boundaries.map(b => parseFloat(b.latitude));
            const lngs = boundaries.map(b => parseFloat(b.longitude));

            res.json({
                success: true,
                campus_type: campusType,
                boundary_points: boundaries.map(b => ({
                    lat: parseFloat(b.latitude),
                    lng: parseFloat(b.longitude),
                    order: b.point_order
                })),
                bounds: {
                    southwest: { lat: Math.min(...lats), lng: Math.min(...lngs) },
                    northeast: { lat: Math.max(...lats), lng: Math.max(...lngs) }
                },
                center: {
                    lat: lats.reduce((a, b) => a + b, 0) / lats.length,
                    lng: lngs.reduce((a, b) => a + b, 0) / lngs.length
                }
            });
        }
    );
});

// ── ALL BUILDINGS ────────────────────────────────────────────────────────────
app.get('/api/campus-map/buildings', (req, res) => {
    const { campus_type, category_id, zoom_level, major_only } = req.query;

    let query = `
        SELECT
            cb.id, cb.name, cb.latitude, cb.longitude,
            cb.entrance_latitude, cb.entrance_longitude,
            cb.campus_type, cb.description, cb.floor_count,
            cb.is_major_building, cb.building_code,
            cb.operational_hours, cb.phone, cb.email, cb.image_url,
            bc.name  AS category_name,
            bc.icon  AS category_icon,
            bc.color AS category_color,
            bc.zoom_level_min
        FROM campus_buildings cb
        LEFT JOIN building_categories bc ON cb.category_id = bc.id
        WHERE cb.status = 'active'
    `;
    const params = [];

    if (campus_type)    { query += ' AND cb.campus_type = ?';      params.push(campus_type); }
    if (category_id)    { query += ' AND cb.category_id = ?';      params.push(category_id); }
    if (zoom_level)     { query += ' AND bc.zoom_level_min <= ?';   params.push(zoom_level); }
    if (major_only === 'true') { query += ' AND cb.is_major_building = 1'; }

    query += ' ORDER BY cb.is_major_building DESC, cb.name ASC';

    db.query(query, params, (err, buildings) => {
        if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });

        if (buildings.length === 0)
            return res.json({ success: true, count: 0, data: [] });

        // Fetch polygons for each building
        let done = 0;
        buildings.forEach((building, idx) => {
            db.query(
                `SELECT corner_number, latitude, longitude
                 FROM building_polygons
                 WHERE building_id = ?
                 ORDER BY corner_number`,
                [building.id],
                (pErr, polygons) => {
                    buildings[idx].polygon_coordinates = (!pErr && polygons.length > 0)
                        ? polygons.map(p => ({ lat: parseFloat(p.latitude), lng: parseFloat(p.longitude), corner: p.corner_number }))
                        : null;
                    if (++done === buildings.length)
                        res.json({ success: true, count: buildings.length, data: buildings });
                }
            );
        });
    });
});

// ── SINGLE BUILDING ──────────────────────────────────────────────────────────
app.get('/api/campus-map/buildings/:id', (req, res) => {
    db.query(
        `SELECT cb.*, bc.name AS category_name, bc.icon AS category_icon, bc.color AS category_color
         FROM campus_buildings cb
         LEFT JOIN building_categories bc ON cb.category_id = bc.id
         WHERE cb.id = ? AND cb.status = 'active'`,
        [req.params.id],
        (err, buildings) => {
            if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            if (buildings.length === 0) return res.status(404).json({ success: false, message: 'Building not found' });

            const building = buildings[0];
            db.query(
                `SELECT corner_number, latitude, longitude
                 FROM building_polygons WHERE building_id = ? ORDER BY corner_number`,
                [building.id],
                (pErr, polygons) => {
                    building.polygon_coordinates = (!pErr && polygons.length > 0)
                        ? polygons.map(p => ({ lat: parseFloat(p.latitude), lng: parseFloat(p.longitude), corner: p.corner_number }))
                        : null;
                    res.json({ success: true, data: building });
                }
            );
        }
    );
});

// ── SEARCH ───────────────────────────────────────────────────────────────────
app.get('/api/campus-map/search', (req, res) => {
    const { q, campus_type } = req.query;
    if (!q || q.trim().length < 2)
        return res.status(400).json({ success: false, message: 'Search query must be at least 2 characters' });

    let query = `
        SELECT cb.id, cb.name, cb.latitude, cb.longitude,
               cb.entrance_latitude, cb.entrance_longitude,
               cb.campus_type, cb.description,
               cb.is_major_building, cb.building_code,
               bc.name AS category_name, bc.icon AS category_icon, bc.color AS category_color
        FROM campus_buildings cb
        LEFT JOIN building_categories bc ON cb.category_id = bc.id
        WHERE cb.status = 'active'
          AND (cb.name LIKE ? OR cb.description LIKE ? OR cb.building_code LIKE ? OR bc.name LIKE ?)
    `;
    const s = `%${q}%`;
    const params = [s, s, s, s];

    if (campus_type) { query += ' AND cb.campus_type = ?'; params.push(campus_type); }
    query += ' ORDER BY cb.is_major_building DESC, cb.name ASC LIMIT 20';

    db.query(query, params, (err, buildings) => {
        if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
        res.json({ success: true, count: buildings.length, data: buildings });
    });
});

// ── NEARBY ───────────────────────────────────────────────────────────────────
app.get('/api/campus-map/nearby', (req, res) => {
    const { latitude, longitude, radius } = req.query;
    if (!latitude || !longitude)
        return res.status(400).json({ success: false, message: 'Latitude and longitude are required' });

    const radiusMeters = radius || 500;

    db.query(
        `SELECT cb.*, bc.name AS category_name, bc.icon AS category_icon, bc.color AS category_color,
                (6371000 * ACOS(
                    COS(RADIANS(?)) * COS(RADIANS(cb.latitude)) *
                    COS(RADIANS(cb.longitude) - RADIANS(?)) +
                    SIN(RADIANS(?)) * SIN(RADIANS(cb.latitude))
                )) AS distance_meters
         FROM campus_buildings cb
         LEFT JOIN building_categories bc ON cb.category_id = bc.id
         WHERE cb.status = 'active'
         HAVING distance_meters <= ?
         ORDER BY distance_meters ASC
         LIMIT 20`,
        [latitude, longitude, latitude, radiusMeters],
        (err, buildings) => {
            if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            res.json({
                success: true,
                center: { lat: parseFloat(latitude), lng: parseFloat(longitude) },
                radius_meters: parseInt(radiusMeters),
                count: buildings.length,
                data: buildings.map(b => ({ ...b, distance_meters: Math.round(parseFloat(b.distance_meters)) }))
            });
        }
    );
});

// ── ROUTE ────────────────────────────────────────────────────────────────────
app.post('/api/campus-map/route', (req, res) => {
    const { from_building_id, to_building_id, from_latitude, from_longitude } = req.body;

    if (!to_building_id)
        return res.status(400).json({ success: false, message: 'to_building_id is required' });

    db.query(
        `SELECT * FROM campus_buildings WHERE id = ? AND status = 'active'`,
        [to_building_id],
        (err, toBuildings) => {
            if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            if (toBuildings.length === 0)
                return res.status(404).json({ success: false, message: 'Destination building not found' });

            const toBuilding = toBuildings[0];

            // ── From current GPS location ──
            if (from_latitude && from_longitude && !from_building_id) {
                const fromLat = parseFloat(from_latitude);
                const fromLng = parseFloat(from_longitude);
                const toLat   = parseFloat(toBuilding.entrance_latitude || toBuilding.latitude);
                const toLng   = parseFloat(toBuilding.entrance_longitude || toBuilding.longitude);
                const dist    = calculateDistanceBetweenPoints(fromLat, fromLng, toLat, toLng);
                const eta     = Math.ceil(dist / 1.4);

                return res.json({
                    success: true,
                    from: { id: -1, name: 'Current Location', latitude: from_latitude, longitude: from_longitude },
                    to: toBuilding,
                    routes: [{ path_id: null, coordinates: [{ lat: fromLat, lng: fromLng }, { lat: toLat, lng: toLng }],
                        waypoints: [], distance_meters: Math.round(dist),
                        estimated_time_seconds: eta, estimated_time_minutes: Math.ceil(eta / 60),
                        path_type: 'direct', is_accessible: true }]
                });
            }

            if (!from_building_id)
                return res.status(400).json({ success: false, message: 'Either from_building_id or from_latitude/longitude required' });

            // ── From building ──
            db.query(
                `SELECT * FROM campus_buildings WHERE id = ? AND status = 'active'`,
                [from_building_id],
                (err2, fromBuildings) => {
                    if (err2) return res.status(500).json({ success: false, message: 'DB error', error: err2.message });
                    if (fromBuildings.length === 0)
                        return res.status(404).json({ success: false, message: 'Source building not found' });

                    const fromBuilding = fromBuildings[0];

                    db.query(
                        `SELECT * FROM campus_paths
                         WHERE from_building_id = ? AND to_building_id = ?
                         ORDER BY path_type = 'main' DESC, distance_meters ASC
                         LIMIT 1`,
                        [from_building_id, to_building_id],
                        (err3, paths) => {
                            if (err3) return res.status(500).json({ success: false, message: 'DB error', error: err3.message });

                            if (paths.length > 0) {
                                const path = paths[0];
                                db.query(
                                    `SELECT waypoint_order, latitude, longitude, waypoint_name
                                     FROM path_waypoints WHERE path_id = ? ORDER BY waypoint_order`,
                                    [path.id],
                                    (err4, waypoints) => {
                                        const coords = JSON.parse(path.path_coordinates);
                                        res.json({
                                            success: true, from: fromBuilding, to: toBuilding,
                                            routes: [{ path_id: path.id, coordinates: coords,
                                                waypoints: (waypoints || []).map(w => ({
                                                    order: w.waypoint_order,
                                                    lat: parseFloat(w.latitude),
                                                    lng: parseFloat(w.longitude),
                                                    name: w.waypoint_name
                                                })),
                                                distance_meters: parseFloat(path.distance_meters),
                                                estimated_time_seconds: path.estimated_time_seconds,
                                                estimated_time_minutes: Math.ceil(path.estimated_time_seconds / 60),
                                                path_type: path.path_type,
                                                is_accessible: path.is_accessible }]
                                        });
                                    }
                                );
                            } else {
                                // Straight-line fallback
                                const fromLat = parseFloat(fromBuilding.entrance_latitude || fromBuilding.latitude);
                                const fromLng = parseFloat(fromBuilding.entrance_longitude || fromBuilding.longitude);
                                const toLat   = parseFloat(toBuilding.entrance_latitude || toBuilding.latitude);
                                const toLng   = parseFloat(toBuilding.entrance_longitude || toBuilding.longitude);
                                const dist    = calculateDistanceBetweenPoints(fromLat, fromLng, toLat, toLng);
                                const eta     = Math.ceil(dist / 1.4);

                                res.json({
                                    success: true, from: fromBuilding, to: toBuilding,
                                    routes: [{ path_id: null,
                                        coordinates: [{ lat: fromLat, lng: fromLng }, { lat: toLat, lng: toLng }],
                                        waypoints: [], distance_meters: Math.round(dist),
                                        estimated_time_seconds: eta, estimated_time_minutes: Math.ceil(eta / 60),
                                        path_type: 'estimated', is_accessible: true, note: 'Estimated direct route' }]
                                });
                            }
                        }
                    );
                }
            );
        }
    );
});

// ── CATEGORIES ───────────────────────────────────────────────────────────────
app.get('/api/campus-map/categories', (req, res) => {
    db.query('SELECT * FROM building_categories ORDER BY name ASC', (err, categories) => {
        if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
        res.json({ success: true, count: categories.length, data: categories });
    });
});

// ── INIT (everything in one call) ────────────────────────────────────────────
app.get('/api/campus-map/init/:campusType', (req, res) => {
    const { campusType } = req.params;

    db.query(
        `SELECT latitude, longitude, point_order
         FROM campus_boundaries WHERE campus_type = ? ORDER BY point_order ASC`,
        [campusType],
        (err, boundaries) => {
            if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            if (boundaries.length === 0)
                return res.status(404).json({ success: false, message: 'Campus not found' });

            db.query(
                `SELECT cb.*, bc.name AS category_name, bc.icon AS category_icon,
                        bc.color AS category_color, bc.zoom_level_min
                 FROM campus_buildings cb
                 LEFT JOIN building_categories bc ON cb.category_id = bc.id
                 WHERE cb.status = 'active' AND cb.campus_type = ?
                 ORDER BY cb.is_major_building DESC, cb.name ASC`,
                [campusType],
                (err2, buildings) => {
                    if (err2) return res.status(500).json({ success: false, message: 'DB error', error: err2.message });

                    db.query('SELECT * FROM building_categories ORDER BY name ASC', (err3, categories) => {
                        if (err3) return res.status(500).json({ success: false, message: 'DB error', error: err3.message });

                        if (buildings.length === 0) {
                            const lats = boundaries.map(b => parseFloat(b.latitude));
                            const lngs = boundaries.map(b => parseFloat(b.longitude));
                            return res.json({
                                success: true, campus_type: campusType,
                                boundaries: {
                                    points: boundaries.map(b => ({ lat: parseFloat(b.latitude), lng: parseFloat(b.longitude), order: b.point_order })),
                                    bounds: { southwest: { lat: Math.min(...lats), lng: Math.min(...lngs) }, northeast: { lat: Math.max(...lats), lng: Math.max(...lngs) } },
                                    center: { lat: lats.reduce((a, b) => a + b, 0) / lats.length, lng: lngs.reduce((a, b) => a + b, 0) / lngs.length }
                                },
                                buildings: { count: 0, data: [] },
                                categories: { count: categories.length, data: categories }
                            });
                        }

                        // Attach polygon data
                        let done = 0;
                        buildings.forEach((building, idx) => {
                            db.query(
                                `SELECT corner_number, latitude, longitude
                                 FROM building_polygons WHERE building_id = ? ORDER BY corner_number`,
                                [building.id],
                                (pErr, polygons) => {
                                    buildings[idx].polygon_coordinates = (!pErr && polygons.length > 0)
                                        ? polygons.map(p => ({ lat: parseFloat(p.latitude), lng: parseFloat(p.longitude), corner: p.corner_number }))
                                        : null;

                                    if (++done === buildings.length) {
                                        const lats = boundaries.map(b => parseFloat(b.latitude));
                                        const lngs = boundaries.map(b => parseFloat(b.longitude));
                                        res.json({
                                            success: true, campus_type: campusType,
                                            boundaries: {
                                                points: boundaries.map(b => ({ lat: parseFloat(b.latitude), lng: parseFloat(b.longitude), order: b.point_order })),
                                                bounds: { southwest: { lat: Math.min(...lats), lng: Math.min(...lngs) }, northeast: { lat: Math.max(...lats), lng: Math.max(...lngs) } },
                                                center: { lat: lats.reduce((a, b) => a + b, 0) / lats.length, lng: lngs.reduce((a, b) => a + b, 0) / lngs.length }
                                            },
                                            buildings: { count: buildings.length, data: buildings },
                                            categories: { count: categories.length, data: categories }
                                        });
                                    }
                                }
                            );
                        });
                    });
                }
            );
        }
    );
});

// ── FAVORITES ────────────────────────────────────────────────────────────────
app.get('/api/campus-map/favorites/:userId', (req, res) => {
    db.query(
        `SELECT uf.id AS favorite_id, uf.nickname, uf.created_at,
                cb.*, bc.name AS category_name, bc.icon AS category_icon, bc.color AS category_color
         FROM user_favorites uf
         JOIN campus_buildings cb ON uf.building_id = cb.id
         LEFT JOIN building_categories bc ON cb.category_id = bc.id
         WHERE uf.user_id = ?
         ORDER BY uf.created_at DESC`,
        [req.params.userId],
        (err, favorites) => {
            if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            res.json({ success: true, count: favorites.length, data: favorites });
        }
    );
});

app.post('/api/campus-map/favorites', (req, res) => {
    const { user_id, building_id, nickname } = req.body;
    if (!user_id || !building_id)
        return res.status(400).json({ success: false, message: 'user_id and building_id are required' });

    db.query(
        'INSERT INTO user_favorites (user_id, building_id, nickname) VALUES (?, ?, ?)',
        [user_id, building_id, nickname || null],
        (err, result) => {
            if (err) {
                if (err.code === 'ER_DUP_ENTRY')
                    return res.status(409).json({ success: false, message: 'Building already in favorites' });
                return res.status(500).json({ success: false, message: 'DB error', error: err.message });
            }
            res.status(201).json({ success: true, message: 'Building added to favorites',
                data: { favorite_id: result.insertId, user_id, building_id, nickname } });
        }
    );
});

app.delete('/api/campus-map/favorites/:favoriteId', (req, res) => {
    db.query('DELETE FROM user_favorites WHERE id = ?', [req.params.favoriteId], (err, result) => {
        if (err) return res.status(500).json({ success: false, message: 'DB error', error: err.message });
        if (result.affectedRows === 0)
            return res.status(404).json({ success: false, message: 'Favorite not found' });
        res.json({ success: true, message: 'Favorite removed successfully' });
    });
});

console.log('✅ Campus Map endpoints initialized (callback style)');

// ================= START SERVER =================
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});