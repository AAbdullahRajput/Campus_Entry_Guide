// ================= IMPORTS =================
const express = require("express");
const mysql = require("mysql2");
const bcrypt = require("bcrypt");
const bodyParser = require("body-parser");
const cors = require("cors");
const nodemailer = require("nodemailer");
const twilio = require("twilio");

// ================= APP SETUP =================
const app = express();
app.use(cors());
app.use(bodyParser.json());

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

    return res.status(200).json({
      message: `${role} logged in successfully`,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        role: role,
        phone_number: user.phone_number || null,
      },
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

// ================= START SERVER =================
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});