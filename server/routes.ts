
import type { Express } from "express";
import type { Server } from "http";
import { storage } from "./storage";
import { api } from "@shared/schema";
import { z } from "zod";

export async function registerRoutes(
  httpServer: Server,
  app: Express
): Promise<Server> {
  
  app.get(api.files.list.path, async (req, res) => {
    const files = await storage.getFiles();
    res.json(files);
  });

  app.post(api.files.create.path, async (req, res) => {
    try {
      const input = api.files.create.input.parse(req.body);
      const file = await storage.createFile(input);
      res.status(201).json(file);
    } catch (err) {
      if (err instanceof z.ZodError) {
        res.status(400).json({ message: "Invalid input" });
      } else {
        res.status(500).json({ message: "Internal server error" });
      }
    }
  });

  app.put(api.files.update.path, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const input = api.files.update.input.parse(req.body);
      const file = await storage.updateFile(id, input);
      if (!file) {
        return res.status(404).json({ message: "File not found" });
      }
      res.json(file);
    } catch (err) {
      if (err instanceof z.ZodError) {
        res.status(400).json({ message: "Invalid input" });
      } else {
        res.status(500).json({ message: "Internal server error" });
      }
    }
  });

  app.delete(api.files.delete.path, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      await storage.deleteFile(id);
      res.status(204).send();
    } catch (err) {
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Seed data if empty
  const existingFiles = await storage.getFiles();
  if (existingFiles.length === 0) {
    await storage.createFile({
      name: "main.py",
      content: `import sys
import js

# This is the main entry point
print("Hello from Python!")
print("<h1>This is HTML output</h1>")

# Example of using the 'js' module to interact with the DOM directly
# (This works in Pyodide!)
# js.document.title = "Updated from Python"
`
    });
    
    await storage.createFile({
      name: "utils.py",
      content: `def greet(name):
    return f"Hello, {name}!"
`
    });

    await storage.createFile({
        name: "example_import.py",
        content: `from utils import greet

print(greet("World"))
`
    });
  }

  return httpServer;
}
